import {
  SignJWT,
  createRemoteJWKSet,
  decodeJwt,
  importPKCS8,
  jwtVerify,
  type JWTPayload
} from "jose";

type Env = WorkerBindings & {
  // Los nombres de Secret bindings no aparecen en wrangler.jsonc por diseño;
  // el resto de bindings se genera mediante `wrangler types`.
  APPLE_IAP_ISSUER_ID: string;
  APPLE_IAP_KEY_ID: string;
  APPLE_IAP_PRIVATE_KEY: string;
  GOOGLE_CLIENT_EMAIL: string;
  GOOGLE_PRIVATE_KEY: string;
};

type AuthContext = {
  uid: string;
  appId: string;
  authTime: number;
};

type FirestoreDocument = {
  name: string;
  fields?: Record<string, FirestoreValue>;
  createTime?: string;
  updateTime?: string;
};

type FirestoreValue =
  | { nullValue: null }
  | { booleanValue: boolean }
  | { integerValue: string }
  | { doubleValue: number }
  | { timestampValue: string }
  | { stringValue: string }
  | { arrayValue: { values?: FirestoreValue[] } }
  | { mapValue: { fields?: Record<string, FirestoreValue> } };

type AppleTransaction = {
  appAccountToken?: string;
  bundleId?: string;
  environment?: string;
  inAppOwnershipType?: string;
  originalTransactionId?: string;
  productId?: string;
  purchaseDate?: number;
  quantity?: number;
  revocationDate?: number;
  transactionId?: string;
  type?: string;
};

type LeagueInput = {
  name: string;
  description: string;
  division: "novato" | "d" | "c" | "b" | "a";
  format: "singles" | "doubles";
  maxMembers: number;
};

type PurchaseBody =
  | {
      kind: "coach";
      productId: "coach_ad_7_days" | "coach_ad_30_days";
      transactionId: string;
      appAccountToken: string;
      adId: string;
    }
  | {
      kind: "league";
      productId: "private_league_create";
      transactionId: string;
      appAccountToken: string;
      league: LeagueInput;
    };

type AndroidPurchaseBody =
  | {
      kind: "coach";
      productId: "coach_ad_7_days" | "coach_ad_30_days";
      purchaseToken: string;
      appAccountToken: string;
      adId: string;
    }
  | {
      kind: "league";
      productId: "private_league_create";
      purchaseToken: string;
      appAccountToken: string;
      league: LeagueInput;
    };

const COACH_PRODUCTS = {
  coach_ad_7_days: { plan: "week", days: 7 },
  coach_ad_30_days: { plan: "month", days: 30 }
} as const;
const LEAGUE_PRODUCT = "private_league_create";
const MAX_BODY_BYTES = 16_384;
const QUERY_PAGE_SIZE = 250;
const MAX_QUERY_DOCUMENTS = 20_000;
const FIREBASE_AUTH_KEYS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);
const APP_CHECK_KEYS = createRemoteJWKSet(
  new URL("https://firebaseappcheck.googleapis.com/v1/jwks")
);

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string
  ) {
    super(message);
  }
}

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff"
    }
  });
}

function logError(message: string, details: Record<string, unknown>): void {
  console.error(JSON.stringify({ message, ...details }));
}

function bearerToken(header: string | null): string {
  if (!header?.startsWith("Bearer ")) throw new HttpError(401, "Falta la sesión.");
  const token = header.slice(7).trim();
  if (!token) throw new HttpError(401, "Falta la sesión.");
  return token;
}

function assertSubject(payload: JWTPayload): string {
  if (typeof payload.sub !== "string" || payload.sub.length < 1 || payload.sub.length > 128) {
    throw new HttpError(401, "Sesión no válida.");
  }
  return payload.sub;
}

async function authenticate(request: Request, env: Env): Promise<AuthContext> {
  const idToken = bearerToken(request.headers.get("Authorization"));
  const appCheckToken = request.headers.get("X-Firebase-AppCheck")?.trim();
  if (!appCheckToken) throw new HttpError(401, "Falta la validación de la app.");

  const [{ payload: authPayload }, { payload: appPayload }] = await Promise.all([
    jwtVerify(idToken, FIREBASE_AUTH_KEYS, {
      algorithms: ["RS256"],
      audience: env.FIREBASE_PROJECT_ID,
      issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`
    }),
    jwtVerify(appCheckToken, APP_CHECK_KEYS, {
      algorithms: ["RS256"],
      audience: `projects/${env.FIREBASE_PROJECT_NUMBER}`,
      issuer: `https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`
    })
  ]);

  const uid = assertSubject(authPayload);
  const appId = assertSubject(appPayload);
  const allowedAppIds: readonly string[] = [env.FIREBASE_IOS_APP_ID, env.FIREBASE_ANDROID_APP_ID];
  if (!allowedAppIds.includes(appId)) {
    throw new HttpError(403, "La app no está autorizada.");
  }
  return {
    uid,
    appId,
    authTime: typeof authPayload.auth_time === "number" ? authPayload.auth_time : 0
  };
}

async function readJson(request: Request): Promise<unknown> {
  const contentType = request.headers.get("Content-Type")?.split(";")[0]?.trim().toLowerCase();
  if (contentType !== "application/json") throw new HttpError(415, "Se esperaba JSON.");
  const declaredLength = Number(request.headers.get("Content-Length") || 0);
  if (declaredLength > MAX_BODY_BYTES) throw new HttpError(413, "Solicitud demasiado grande.");
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    throw new HttpError(413, "Solicitud demasiado grande.");
  }
  try {
    return JSON.parse(raw);
  } catch {
    throw new HttpError(400, "JSON no válido.");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function boundedString(value: unknown, min: number, max: number, label: string): string {
  if (typeof value !== "string") throw new HttpError(400, `${label} no válido.`);
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) {
    throw new HttpError(400, `${label} no válido.`);
  }
  return normalized;
}

function validateLeague(value: unknown): LeagueInput {
  if (!isRecord(value)) throw new HttpError(400, "Datos de liga no válidos.");
  const division = value.division;
  const format = value.format;
  const maxMembers = value.maxMembers;
  if (!["novato", "d", "c", "b", "a"].includes(String(division))) {
    throw new HttpError(400, "División no válida.");
  }
  if (!["singles", "doubles"].includes(String(format))) {
    throw new HttpError(400, "Formato no válido.");
  }
  if (!Number.isInteger(maxMembers) || Number(maxMembers) < 2 || Number(maxMembers) > 32) {
    throw new HttpError(400, "Número de miembros no válido.");
  }
  return {
    name: boundedString(value.name, 3, 80, "Nombre"),
    description: typeof value.description === "string" ? value.description.trim().slice(0, 400) : "",
    division: division as LeagueInput["division"],
    format: format as LeagueInput["format"],
    maxMembers: Number(maxMembers)
  };
}

export function validateAccountDeletionBody(value: unknown): void {
  if (!isRecord(value) || value.confirmation !== "DELETE_ACCOUNT") {
    throw new HttpError(400, "Confirmación de eliminación no válida.");
  }
}

export function hasRecentAuthentication(authTime: number, nowMs = Date.now()): boolean {
  if (!Number.isFinite(authTime) || authTime <= 0) return false;
  const ageSeconds = nowMs / 1000 - authTime;
  return ageSeconds >= -300 && ageSeconds <= 10 * 60;
}

export function validatePurchaseBody(value: unknown): PurchaseBody {
  if (!isRecord(value)) throw new HttpError(400, "Compra no válida.");
  const transactionId = boundedString(value.transactionId, 1, 80, "Transacción");
  if (!/^[0-9]+$/.test(transactionId)) throw new HttpError(400, "Transacción no válida.");
  const appAccountToken = boundedString(value.appAccountToken, 36, 36, "Cuenta");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(appAccountToken)) {
    throw new HttpError(400, "Cuenta no válida.");
  }
  if (value.kind === "coach") {
    if (!(value.productId === "coach_ad_7_days" || value.productId === "coach_ad_30_days")) {
      throw new HttpError(400, "Producto no válido.");
    }
    return {
      kind: "coach",
      productId: value.productId,
      transactionId,
      appAccountToken,
      adId: boundedString(value.adId, 1, 150, "Anuncio")
    };
  }
  if (value.kind === "league" && value.productId === LEAGUE_PRODUCT) {
    return {
      kind: "league",
      productId: LEAGUE_PRODUCT,
      transactionId,
      appAccountToken,
      league: validateLeague(value.league)
    };
  }
  throw new HttpError(400, "Producto no válido.");
}

export function validateAndroidPurchaseBody(value: unknown): AndroidPurchaseBody {
  if (!isRecord(value)) throw new HttpError(400, "Compra no válida.");
  const purchaseToken = boundedString(value.purchaseToken, 10, 512, "Token de compra");
  const appAccountToken = boundedString(value.appAccountToken, 36, 36, "Cuenta");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(appAccountToken)) {
    throw new HttpError(400, "Cuenta no válida.");
  }
  if (value.kind === "coach") {
    if (!(value.productId === "coach_ad_7_days" || value.productId === "coach_ad_30_days")) {
      throw new HttpError(400, "Producto no válido.");
    }
    return {
      kind: "coach",
      productId: value.productId,
      purchaseToken,
      appAccountToken,
      adId: boundedString(value.adId, 1, 150, "Anuncio")
    };
  }
  if (value.kind === "league" && value.productId === LEAGUE_PRODUCT) {
    return {
      kind: "league",
      productId: LEAGUE_PRODUCT,
      purchaseToken,
      appAccountToken,
      league: validateLeague(value.league)
    };
  }
  throw new HttpError(400, "Producto no válido.");
}

export async function accountTokenForUid(uid: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(uid))).slice(0, 16);
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x50;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const hex = [...bytes].map((value) => value.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function normalizePrivateKey(value: string): string {
  return value.includes("\\n") ? value.replaceAll("\\n", "\n") : value;
}

async function appleAuthorization(env: Env): Promise<string> {
  const key = await importPKCS8(normalizePrivateKey(env.APPLE_IAP_PRIVATE_KEY), "ES256");
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ bid: env.APPLE_BUNDLE_ID })
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_IAP_KEY_ID, typ: "JWT" })
    .setIssuer(env.APPLE_IAP_ISSUER_ID)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt(now)
    .setExpirationTime(now + 10 * 60)
    .sign(key);
}

async function fetchAppleTransaction(transactionId: string, env: Env): Promise<AppleTransaction> {
  const authorization = await appleAuthorization(env);
  const bases = [
    "https://api.storekit.itunes.apple.com",
    "https://api.storekit-sandbox.itunes.apple.com"
  ];
  for (const [index, base] of bases.entries()) {
    const response = await fetch(`${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: {
        Authorization: `Bearer ${authorization}`,
        Accept: "application/json"
      }
    });
    if (response.status === 404 && index === 0) continue;
    if (!response.ok) {
      logError("Apple transaction lookup failed", { status: response.status, environmentIndex: index });
      throw new HttpError(response.status >= 500 ? 503 : 400, "App Store no pudo validar la compra.");
    }
    const result = await response.json() as { signedTransactionInfo?: unknown };
    if (typeof result.signedTransactionInfo !== "string") {
      throw new HttpError(502, "Respuesta de App Store no válida.");
    }
    return decodeJwt(result.signedTransactionInfo) as AppleTransaction;
  }
  throw new HttpError(400, "App Store no reconoce la transacción.");
}

function validateAppleTransaction(
  transaction: AppleTransaction,
  body: PurchaseBody,
  expectedAccountToken: string,
  env: Env
): void {
  if (
    transaction.transactionId !== body.transactionId
    || transaction.productId !== body.productId
    || transaction.bundleId !== env.APPLE_BUNDLE_ID
    || transaction.appAccountToken?.toLowerCase() !== expectedAccountToken
  ) {
    throw new HttpError(403, "La compra no pertenece a esta cuenta.");
  }
  if (transaction.revocationDate || transaction.quantity !== 1) {
    throw new HttpError(400, "La compra no es válida.");
  }
  if (transaction.type && transaction.type !== "Consumable") {
    throw new HttpError(400, "El tipo de compra no es válido.");
  }
  if (transaction.inAppOwnershipType && transaction.inAppOwnershipType !== "PURCHASED") {
    throw new HttpError(400, "La compra no pertenece al usuario.");
  }
  if (!transaction.purchaseDate || transaction.purchaseDate > Date.now() + 5 * 60_000) {
    throw new HttpError(400, "La fecha de compra no es válida.");
  }
}

async function googleAccessToken(env: Env): Promise<string> {
  return googleScopedAccessToken(env, "https://www.googleapis.com/auth/datastore");
}

/**
 * Token de Google con scope para la Play Developer API. Permite verificar
 * compras in-app de Android llamando a androidpublisher.googleapis.com.
 */
async function googlePlayAccessToken(env: Env): Promise<string> {
  return googleScopedAccessToken(env, "https://www.googleapis.com/auth/androidpublisher");
}

async function googleIdentityAccessToken(env: Env): Promise<string> {
  return googleScopedAccessToken(env, "https://www.googleapis.com/auth/identitytoolkit");
}

async function googleScopedAccessToken(env: Env, scope: string): Promise<string> {
  const key = await importPKCS8(normalizePrivateKey(env.GOOGLE_PRIVATE_KEY), "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({ scope })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(env.GOOGLE_CLIENT_EMAIL)
    .setSubject(env.GOOGLE_CLIENT_EMAIL)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 55 * 60)
    .sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });
  if (!response.ok) {
    logError("Google OAuth failed", { status: response.status, scope });
    throw new HttpError(503, "No se pudo completar la entrega.");
  }
  const result = await response.json() as { access_token?: unknown };
  if (typeof result.access_token !== "string") throw new HttpError(503, "No se pudo completar la entrega.");
  return result.access_token;
}

type GooglePlayPurchase = {
  purchaseState: number;
  consumptionState: number;
  productId: string;
  purchaseTimeMillis: string;
  orderId: string;
  purchaseToken: string;
  quantity: number;
  acknowledgementState: number;
  obfuscatedExternalAccountId?: string;
};

/**
 * Consulta la Google Play Developer API para verificar que el purchaseToken
 * corresponde a una compra real y válida del producto esperado.
 */
async function fetchGooglePlayPurchase(
  productId: string,
  purchaseToken: string,
  env: Env
): Promise<GooglePlayPurchase> {
  const accessToken = await googlePlayAccessToken(env);
  const packageName = env.ANDROID_PACKAGE_NAME;
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json"
    }
  });
  if (!response.ok) {
    logError("Google Play purchase lookup failed", { status: response.status });
    throw new HttpError(response.status >= 500 ? 503 : 400, "Google Play no pudo validar la compra.");
  }
  const result = await response.json() as Partial<GooglePlayPurchase>;
  if (!result.productId || !result.purchaseToken) {
    throw new HttpError(502, "Respuesta de Google Play no válida.");
  }
  return result as GooglePlayPurchase;
}

function validateGooglePlayPurchase(
  purchase: GooglePlayPurchase,
  body: AndroidPurchaseBody,
  expectedAccountToken: string
): void {
  if (purchase.productId !== body.productId) {
    throw new HttpError(403, "El producto no coincide con la compra.");
  }
  // 0 = purchased, 1 = canceled, 2 = pending
  if (purchase.purchaseState !== 0) {
    throw new HttpError(400, "La compra no está completada.");
  }
  // 0 = yet to be consumed, 1 = consumed — los consumibles deben estar ack'd
  if (purchase.acknowledgementState !== 1) {
    // No bloqueamos: el cliente hace acknowledge tras la verificación.
  }
  if (purchase.quantity !== 1) {
    throw new HttpError(400, "La cantidad de compra no es válida.");
  }
  // Verificamos que el obfuscatedAccountId (que el cliente setea con el
  // appAccountToken derivado del uid) coincida con el esperado.
  if (purchase.obfuscatedExternalAccountId?.toLowerCase() !== expectedAccountToken) {
    throw new HttpError(403, "La compra no pertenece a esta cuenta.");
  }
}

function documentUrl(env: Env, path: string): string {
  const safePath = path.split("/").map(encodeURIComponent).join("/");
  return `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${safePath}`;
}

async function getDocument(env: Env, token: string, path: string): Promise<FirestoreDocument | null> {
  const response = await fetch(documentUrl(env, path), {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    logError("Firestore read failed", { status: response.status, path });
    throw new HttpError(503, "No se pudo completar la entrega.");
  }
  return response.json() as Promise<FirestoreDocument>;
}

function fromFirestore(value: FirestoreValue | undefined): unknown {
  if (!value) return undefined;
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("stringValue" in value) return value.stringValue;
  if ("arrayValue" in value) return (value.arrayValue.values ?? []).map(fromFirestore);
  if ("mapValue" in value) return decodeFields(value.mapValue.fields ?? {});
  return undefined;
}

function decodeFields(fields: Record<string, FirestoreValue>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, fromFirestore(value)]));
}

function toFirestore(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toFirestore) } };
  if (isRecord(value)) return { mapValue: { fields: encodeFields(value) } };
  throw new HttpError(500, "No se pudo completar la entrega.");
}

function encodeFields(value: Record<string, unknown>): Record<string, FirestoreValue> {
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, toFirestore(item)]));
}

function docName(env: Env, path: string): string {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`;
}

type FirestoreWrite =
  | {
      update: { name: string; fields: Record<string, FirestoreValue> };
      updateMask?: { fieldPaths: string[] };
      currentDocument?: { exists?: boolean; updateTime?: string };
    }
  | {
      delete: string;
      currentDocument?: { exists?: boolean; updateTime?: string };
    };

async function commit(env: Env, token: string, writes: FirestoreWrite[]): Promise<void> {
  if (writes.length === 0) return;
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ writes })
    }
  );
  if (!response.ok) {
    logError("Firestore commit failed", { status: response.status });
    throw new HttpError(response.status === 409 ? 409 : 503, "No se pudo completar la entrega.");
  }
}

async function commitAll(env: Env, token: string, writes: FirestoreWrite[]): Promise<void> {
  // Firestore admite 500 escrituras por commit. Dejamos margen para que este
  // flujo siga siendo seguro si se añaden transforms o verificaciones.
  for (let index = 0; index < writes.length; index += 400) {
    await commit(env, token, writes.slice(index, index + 400));
  }
}

function createWrite(env: Env, path: string, fields: Record<string, unknown>): FirestoreWrite {
  return {
    update: { name: docName(env, path), fields: encodeFields(fields) },
    currentDocument: { exists: false }
  };
}

function updateWrite(
  env: Env,
  path: string,
  fields: Record<string, unknown>,
  updateTime: string
): FirestoreWrite {
  return {
    update: { name: docName(env, path), fields: encodeFields(fields) },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: { updateTime }
  };
}

function deleteWrite(env: Env, path: string, updateTime?: string): FirestoreWrite {
  return {
    delete: docName(env, path),
    ...(updateTime ? { currentDocument: { updateTime } } : {})
  };
}

type FirestoreQueryOperator = "EQUAL" | "ARRAY_CONTAINS";

async function queryDocuments(
  env: Env,
  token: string,
  collectionId: string,
  fieldPath: string,
  op: FirestoreQueryOperator,
  value: unknown
): Promise<FirestoreDocument[]> {
  const documents: FirestoreDocument[] = [];
  let cursor: string | undefined;
  do {
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          structuredQuery: {
            from: [{ collectionId }],
            where: {
              fieldFilter: {
                field: { fieldPath },
                op,
                value: toFirestore(value)
              }
            },
            orderBy: [{ field: { fieldPath: "__name__" }, direction: "ASCENDING" }],
            ...(cursor ? {
              startAt: {
                values: [{ referenceValue: cursor }],
                // En un cursor de inicio, false equivale a startAfter.
                before: false
              }
            } : {}),
            limit: QUERY_PAGE_SIZE
          }
        })
      }
    );
    if (!response.ok) {
      logError("Firestore query failed", { status: response.status, collectionId, fieldPath, op });
      throw new HttpError(503, "No se pudo completar la eliminación.");
    }
    const results = await response.json() as Array<{ document?: FirestoreDocument }>;
    const page = results.flatMap((item) => item.document ? [item.document] : []);
    documents.push(...page);
    if (documents.length > MAX_QUERY_DOCUMENTS) {
      throw new HttpError(409, "La cuenta contiene demasiados registros para el borrado automático. Contacta con soporte.");
    }
    cursor = page.at(-1)?.name;
    if (page.length < QUERY_PAGE_SIZE) break;
  } while (cursor);
  return documents;
}

function pathFromDocument(env: Env, document: FirestoreDocument): string {
  const prefix = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/`;
  if (!document.name.startsWith(prefix)) {
    throw new HttpError(503, "No se pudo completar la eliminación.");
  }
  return document.name.slice(prefix.length);
}

function inviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return [...bytes].map((value) => chars[value % chars.length]).join("");
}

async function deliverPurchase(
  body: PurchaseBody,
  transaction: AppleTransaction,
  uid: string,
  env: Env
): Promise<Record<string, unknown>> {
  const token = await googleAccessToken(env);
  const purchasePath = `iapPurchases/${body.transactionId}`;
  const previous = await getDocument(env, token, purchasePath);
  if (previous) {
    const stored = decodeFields(previous.fields ?? {});
    if (stored.ownerId !== uid || stored.productId !== body.productId) {
      throw new HttpError(409, "La transacción ya fue utilizada.");
    }
    return {
      verified: true,
      repeated: true,
      kind: stored.kind,
      adId: stored.adId,
      leagueId: stored.leagueId
    };
  }

  const now = new Date();
  const basePurchase = {
    ownerId: uid,
    productId: body.productId,
    transactionId: body.transactionId,
    originalTransactionId: transaction.originalTransactionId ?? body.transactionId,
    platform: "ios",
    environment: transaction.environment ?? "unknown",
    purchaseDate: new Date(transaction.purchaseDate ?? now.getTime()),
    verifiedAt: now,
    status: "verified",
    kind: body.kind
  };

  if (body.kind === "coach") {
    const adPath = `coachAds/${body.adId}`;
    const adDocument = await getDocument(env, token, adPath);
    if (!adDocument?.updateTime) throw new HttpError(404, "El anuncio ya no existe.");
    const ad = decodeFields(adDocument.fields ?? {});
    const product = COACH_PRODUCTS[body.productId];
    if (ad.ownerId !== uid || ad.plan !== product.plan || !["pending_payment", "active"].includes(String(ad.status))) {
      throw new HttpError(403, "El anuncio no coincide con la compra.");
    }
    const previousExpiry = typeof ad.expiresAt === "string" ? Date.parse(ad.expiresAt) : 0;
    const activeFrom = now;
    const expiresAt = new Date(Math.max(Date.now(), previousExpiry) + product.days * 86_400_000);
    await commit(env, token, [
      createWrite(env, purchasePath, { ...basePurchase, adId: body.adId }),
      updateWrite(env, adPath, { status: "active", activeFrom, expiresAt, updatedAt: now }, adDocument.updateTime)
    ]);
    return { verified: true, repeated: false, kind: "coach", adId: body.adId };
  }

  const leagueId = crypto.randomUUID().replaceAll("-", "");
  const code = inviteCode();
  await commit(env, token, [
    createWrite(env, purchasePath, { ...basePurchase, leagueId }),
    createWrite(env, `privateLeagues/${leagueId}`, {
      id: leagueId,
      ownerId: uid,
      name: body.league.name,
      description: body.league.description,
      division: body.league.division,
      format: body.league.format,
      maxMembers: body.league.maxMembers,
      memberIds: [uid],
      createdAt: now
    }),
    createWrite(env, `privateLeagues/${leagueId}/private/invite`, {
      code,
      createdAt: now
    })
  ]);
  return { verified: true, repeated: false, kind: "league", leagueId };
}

async function verifyApplePurchase(request: Request, auth: AuthContext, env: Env): Promise<Response> {
  if (auth.appId !== env.FIREBASE_IOS_APP_ID) throw new HttpError(403, "Esta compra solo está disponible en iOS.");
  const body = validatePurchaseBody(await readJson(request));
  const expectedAccountToken = await accountTokenForUid(auth.uid);
  if (body.appAccountToken.toLowerCase() !== expectedAccountToken) {
    throw new HttpError(403, "La compra no pertenece a esta cuenta.");
  }
  const transaction = await fetchAppleTransaction(body.transactionId, env);
  validateAppleTransaction(transaction, body, expectedAccountToken, env);
  return json(await deliverPurchase(body, transaction, auth.uid, env));
}

/**
 * Entrega una compra de Android verificada. La estructura es la misma que
 * iOS: crea iapPurchases/{orderId} (idempotente) y actualiza el anuncio o
 * crea la liga privada según el tipo de producto.
 */
async function deliverAndroidPurchase(
  body: AndroidPurchaseBody,
  purchase: GooglePlayPurchase,
  uid: string,
  env: Env
): Promise<Record<string, unknown>> {
  const token = await googleAccessToken(env);
  // Usamos orderId como identificador único de la compra (equivalente al
  // transactionId de Apple). Si no hay orderId, caemos al purchaseToken.
  const purchaseId = purchase.orderId || `android-${body.purchaseToken.slice(0, 40)}`;
  const purchasePath = `iapPurchases/${purchaseId}`;
  const previous = await getDocument(env, token, purchasePath);
  if (previous) {
    const stored = decodeFields(previous.fields ?? {});
    if (stored.ownerId !== uid || stored.productId !== body.productId) {
      throw new HttpError(409, "La transacción ya fue utilizada.");
    }
    return {
      verified: true,
      repeated: true,
      kind: stored.kind,
      adId: stored.adId,
      leagueId: stored.leagueId
    };
  }

  const now = new Date();
  const basePurchase = {
    ownerId: uid,
    productId: body.productId,
    transactionId: purchaseId,
    originalTransactionId: purchaseId,
    purchaseToken: body.purchaseToken,
    platform: "android",
    environment: "production",
    purchaseDate: new Date(Number(purchase.purchaseTimeMillis) || now.getTime()),
    verifiedAt: now,
    status: "verified",
    kind: body.kind
  };

  if (body.kind === "coach") {
    const adPath = `coachAds/${body.adId}`;
    const adDocument = await getDocument(env, token, adPath);
    if (!adDocument?.updateTime) throw new HttpError(404, "El anuncio ya no existe.");
    const ad = decodeFields(adDocument.fields ?? {});
    const product = COACH_PRODUCTS[body.productId];
    if (ad.ownerId !== uid || ad.plan !== product.plan || !["pending_payment", "active"].includes(String(ad.status))) {
      throw new HttpError(403, "El anuncio no coincide con la compra.");
    }
    const previousExpiry = typeof ad.expiresAt === "string" ? Date.parse(ad.expiresAt) : 0;
    const activeFrom = now;
    const expiresAt = new Date(Math.max(Date.now(), previousExpiry) + product.days * 86_400_000);
    await commit(env, token, [
      createWrite(env, purchasePath, { ...basePurchase, adId: body.adId }),
      updateWrite(env, adPath, { status: "active", activeFrom, expiresAt, updatedAt: now }, adDocument.updateTime)
    ]);
    return { verified: true, repeated: false, kind: "coach", adId: body.adId };
  }

  const leagueId = crypto.randomUUID().replaceAll("-", "");
  const code = inviteCode();
  await commit(env, token, [
    createWrite(env, purchasePath, { ...basePurchase, leagueId }),
    createWrite(env, `privateLeagues/${leagueId}`, {
      id: leagueId,
      ownerId: uid,
      name: body.league.name,
      description: body.league.description,
      division: body.league.division,
      format: body.league.format,
      maxMembers: body.league.maxMembers,
      memberIds: [uid],
      createdAt: now
    }),
    createWrite(env, `privateLeagues/${leagueId}/private/invite`, {
      code,
      createdAt: now
    })
  ]);
  return { verified: true, repeated: false, kind: "league", leagueId };
}

async function verifyAndroidPurchase(request: Request, auth: AuthContext, env: Env): Promise<Response> {
  if (auth.appId !== env.FIREBASE_ANDROID_APP_ID) throw new HttpError(403, "Esta compra solo está disponible en Android.");
  const body = validateAndroidPurchaseBody(await readJson(request));
  const expectedAccountToken = await accountTokenForUid(auth.uid);
  if (body.appAccountToken.toLowerCase() !== expectedAccountToken) {
    throw new HttpError(403, "La compra no pertenece a esta cuenta.");
  }
  const purchase = await fetchGooglePlayPurchase(body.productId, body.purchaseToken, env);
  validateGooglePlayPurchase(purchase, body, expectedAccountToken);
  return json(await deliverAndroidPurchase(body, purchase, auth.uid, env));
}

function uniqueDocuments(env: Env, groups: FirestoreDocument[][]): FirestoreDocument[] {
  const documents = new Map<string, FirestoreDocument>();
  for (const document of groups.flat()) documents.set(pathFromDocument(env, document), document);
  return [...documents.values()];
}

function replaceUid(items: unknown, uid: string, replacement: string): unknown[] | null {
  if (!Array.isArray(items)) return null;
  return items.map((item) => item === uid ? replacement : item);
}

function redactIdentityMap(
  value: unknown,
  uid: string,
  replacement: string,
  idField: string,
  nameField: string
): Record<string, unknown> | null {
  if (!isRecord(value) || value[idField] !== uid) return null;
  return { ...value, [idField]: replacement, [nameField]: "Usuario eliminado" };
}

async function deleteFirebaseAuthUser(uid: string, env: Env): Promise<void> {
  const token = await googleIdentityAccessToken(env);
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/accounts:delete`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ localId: uid })
    }
  );
  if (!response.ok) {
    logError("Firebase Auth deletion failed", { status: response.status });
    throw new HttpError(503, "Los datos se limpiaron, pero no se pudo cerrar la cuenta. Vuelve a intentarlo.");
  }
}

async function deleteAccount(request: Request, auth: AuthContext, env: Env): Promise<Response> {
  validateAccountDeletionBody(await readJson(request));
  if (!hasRecentAuthentication(auth.authTime)) {
    throw new HttpError(403, "Por seguridad, cierra sesión, vuelve a entrar y repite la eliminación.");
  }

  const token = await googleAccessToken(env);
  const uid = auth.uid;
  const now = new Date();
  const tombstone = `deleted-${crypto.randomUUID()}`;
  const equal = (collectionId: string, fieldPath: string) =>
    queryDocuments(env, token, collectionId, fieldPath, "EQUAL", uid);
  const contains = (collectionId: string, fieldPath: string) =>
    queryDocuments(env, token, collectionId, fieldPath, "ARRAY_CONTAINS", uid);

  const [
    ownedMatches,
    acceptedMatches,
    doublesMatches,
    reviewsAuthored,
    reviewsReceived,
    requestsOwned,
    requestsMade,
    notificationsReceived,
    notificationsSent,
    coachAds,
    coachInterestsOwned,
    coachInterestsMade,
    leaguesOwned,
    leaguesJoined,
    purchases,
    singlesPlayerA,
    singlesPlayerB,
    singlesWinner,
    singlesValidator,
    doublesTeamA,
    doublesTeamB,
    doublesValidator
  ] = await Promise.all([
    equal("matches", "fromPlayerId"),
    equal("matches", "acceptedByPlayerId"),
    contains("matches", "participantIds"),
    equal("matchReviews", "authorId"),
    equal("matchReviews", "targetId"),
    equal("matchJoinRequests", "ownerId"),
    equal("matchJoinRequests", "requesterId"),
    equal("notifications", "recipientId"),
    equal("notifications", "actorId"),
    equal("coachAds", "ownerId"),
    equal("coachInterests", "coachOwnerId"),
    equal("coachInterests", "interestedUserId"),
    equal("privateLeagues", "ownerId"),
    contains("privateLeagues", "memberIds"),
    equal("iapPurchases", "ownerId"),
    equal("rankingResults", "playerAId"),
    equal("rankingResults", "playerBId"),
    equal("rankingResults", "winnerId"),
    equal("rankingResults", "validatedById"),
    contains("doublesRankingResults", "teamAIds"),
    contains("doublesRankingResults", "teamBIds"),
    equal("doublesRankingResults", "validatedById")
  ]);

  const planned = new Map<string, FirestoreWrite>();
  const planDelete = (path: string, updateTime?: string) => {
    planned.set(path, deleteWrite(env, path, updateTime));
  };
  const planUpdate = (document: FirestoreDocument, fields: Record<string, unknown>) => {
    if (!document.updateTime) throw new HttpError(503, "No se pudo completar la eliminación.");
    const path = pathFromDocument(env, document);
    const previous = planned.get(path);
    if (previous && "delete" in previous) return;
    planned.set(path, updateWrite(env, path, fields, document.updateTime));
  };

  // Contenido efímero o directamente personal: se elimina por completo.
  for (const document of uniqueDocuments(env, [
    reviewsAuthored,
    reviewsReceived,
    requestsOwned,
    requestsMade,
    notificationsReceived,
    notificationsSent,
    coachInterestsOwned,
    coachInterestsMade
  ])) {
    planDelete(pathFromDocument(env, document), document.updateTime);
  }

  for (const document of coachAds) {
    const path = pathFromDocument(env, document);
    planDelete(`${path}/private/contact`);
    planDelete(path, document.updateTime);
  }

  const ownedLeaguePaths = new Set(leaguesOwned.map((document) => pathFromDocument(env, document)));
  for (const document of leaguesOwned) {
    const path = pathFromDocument(env, document);
    planDelete(`${path}/private/invite`);
    planDelete(path, document.updateTime);
  }
  for (const document of leaguesJoined) {
    const path = pathFromDocument(env, document);
    if (ownedLeaguePaths.has(path)) continue;
    const league = decodeFields(document.fields ?? {});
    const memberIds = Array.isArray(league.memberIds)
      ? league.memberIds.filter((item) => item !== uid)
      : [];
    planUpdate(document, { memberIds, updatedAt: now });
  }

  // Las referencias de tienda pueden ser necesarias para reembolsos y fraude,
  // pero ya no conservan el UID ni el token secreto de Google Play.
  for (const document of purchases) {
    planUpdate(document, {
      ownerId: tombstone,
      purchaseToken: null,
      anonymizedAt: now
    });
  }

  const matches = uniqueDocuments(env, [ownedMatches, acceptedMatches, doublesMatches]);
  for (const document of matches) {
    const path = pathFromDocument(env, document);
    const match = decodeFields(document.fields ?? {});
    const startsAt = Date.parse(String(match.startsAt ?? ""));
    const future = Number.isFinite(startsAt) && startsAt > now.getTime();
    const owned = match.fromPlayerId === uid;
    const participants = Array.isArray(match.participantIds) ? match.participantIds : [];
    const doubles = participants.includes(uid);
    const acceptedHistorical = match.status === "accepted" && !future;

    if ((owned && !acceptedHistorical) || (doubles && future)) {
      planDelete(path, document.updateTime);
      const matchId = path.split("/").at(-1)!;
      planDelete(`rankingResults/${matchId}`);
      planDelete(`doublesRankingResults/${matchId}`);
      continue;
    }

    if (!acceptedHistorical) {
      if (match.acceptedByPlayerId === uid) {
        planUpdate(document, {
          acceptedByPlayerId: null,
          status: future ? "proposed" : "declined",
          updatedAt: now
        });
      }
      continue;
    }

    const fields: Record<string, unknown> = { anonymizedAt: now, updatedAt: now };
    if (match.fromPlayerId === uid) fields.fromPlayerId = tombstone;
    if (match.acceptedByPlayerId === uid) fields.acceptedByPlayerId = tombstone;
    for (const field of ["teamAIds", "teamBIds", "participantIds"] as const) {
      const replaced = replaceUid(match[field], uid, tombstone);
      if (replaced) fields[field] = replaced;
    }
    const result = redactIdentityMap(match.result, uid, tombstone, "reportedById", "reportedByName");
    const validation = redactIdentityMap(match.validation, uid, tombstone, "playerId", "playerName");
    if (result) fields.result = result;
    if (validation) fields.validation = validation;
    planUpdate(document, fields);
  }

  for (const document of uniqueDocuments(env, [
    singlesPlayerA,
    singlesPlayerB,
    singlesWinner,
    singlesValidator
  ])) {
    const result = decodeFields(document.fields ?? {});
    const fields: Record<string, unknown> = { anonymizedAt: now };
    for (const field of ["playerAId", "playerBId", "winnerId", "validatedById"] as const) {
      if (result[field] === uid) fields[field] = tombstone;
    }
    planUpdate(document, fields);
  }

  for (const document of uniqueDocuments(env, [doublesTeamA, doublesTeamB, doublesValidator])) {
    const result = decodeFields(document.fields ?? {});
    const fields: Record<string, unknown> = { anonymizedAt: now };
    for (const field of ["teamAIds", "teamBIds"] as const) {
      const replaced = replaceUid(result[field], uid, tombstone);
      if (replaced) fields[field] = replaced;
    }
    if (result.validatedById === uid) fields.validatedById = tombstone;
    planUpdate(document, fields);
  }

  for (const path of [
    `teamSeekers/${uid}`,
    `androidBetaRequests/${uid}`,
    `players/${uid}`,
    `users/${uid}`
  ]) {
    planDelete(path);
  }

  await commitAll(env, token, [...planned.values()]);
  // Auth se elimina al final: si una escritura falla, la persona conserva la
  // sesión y puede repetir sin quedar atrapada en un estado parcial.
  await deleteFirebaseAuthUser(uid, env);
  return json({ deleted: true });
}

async function joinLeague(request: Request, auth: AuthContext, env: Env): Promise<Response> {
  const body = await readJson(request);
  if (!isRecord(body)) throw new HttpError(400, "Invitación no válida.");
  const leagueId = boundedString(body.leagueId, 1, 150, "Liga");
  const code = boundedString(body.inviteCode, 8, 8, "Código").toUpperCase();
  if (!/^[A-HJ-NP-Z2-9]{8}$/.test(code)) throw new HttpError(400, "Código no válido.");

  const token = await googleAccessToken(env);
  const leaguePath = `privateLeagues/${leagueId}`;
  const [leagueDocument, inviteDocument] = await Promise.all([
    getDocument(env, token, leaguePath),
    getDocument(env, token, `${leaguePath}/private/invite`)
  ]);
  if (!leagueDocument?.updateTime || !inviteDocument) throw new HttpError(404, "La liga ya no existe.");
  const league = decodeFields(leagueDocument.fields ?? {});
  const invite = decodeFields(inviteDocument.fields ?? {});
  if (invite.code !== code) throw new HttpError(403, "El código de invitación no es válido.");
  const members = Array.isArray(league.memberIds)
    ? league.memberIds.filter((item): item is string => typeof item === "string")
    : [];
  if (members.includes(auth.uid)) return json({ joined: true, leagueId, repeated: true });
  if (members.length >= Number(league.maxMembers ?? 0)) throw new HttpError(409, "La liga ya está completa.");
  await commit(env, token, [
    updateWrite(env, leaguePath, { memberIds: [...members, auth.uid], updatedAt: new Date() }, leagueDocument.updateTime)
  ]);
  return json({ joined: true, leagueId, repeated: false });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, service: "matchpoint-iap-verifier" });
      }
      if (request.method !== "POST") throw new HttpError(405, "Método no permitido.");
      const auth = await authenticate(request, env);
      if (url.pathname === "/v1/apple/verify") return verifyApplePurchase(request, auth, env);
      if (url.pathname === "/v1/android/verify") return verifyAndroidPurchase(request, auth, env);
      if (url.pathname === "/v1/leagues/join") return joinLeague(request, auth, env);
      if (url.pathname === "/v1/account/delete") return deleteAccount(request, auth, env);
      throw new HttpError(404, "Ruta no encontrada.");
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      if (error instanceof Error && ["JWTExpired", "JWSSignatureVerificationFailed", "JWTClaimValidationFailed"].includes(error.name)) {
        return json({ error: "Sesión o validación de app no válida." }, 401);
      }
      logError("Unhandled request error", error instanceof Error
        ? { name: error.name, detail: error.message }
        : { detail: "unknown" });
      return json({ error: "Error temporal del servicio." }, 503);
    }
  }
} satisfies ExportedHandler<Env>;
