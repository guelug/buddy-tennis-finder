import {
  SignJWT,
  createRemoteJWKSet,
  decodeJwt,
  importPKCS8,
  jwtVerify,
  type JWTPayload
} from "jose";

type Env = {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_PROJECT_NUMBER: string;
  FIREBASE_IOS_APP_ID: string;
  FIREBASE_ANDROID_APP_ID: string;
  APPLE_BUNDLE_ID: string;
  APPLE_IAP_ISSUER_ID: string;
  APPLE_IAP_KEY_ID: string;
  APPLE_IAP_PRIVATE_KEY: string;
  GOOGLE_CLIENT_EMAIL: string;
  GOOGLE_PRIVATE_KEY: string;
};

type AuthContext = {
  uid: string;
  appId: string;
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

const COACH_PRODUCTS = {
  coach_ad_7_days: { plan: "week", days: 7 },
  coach_ad_30_days: { plan: "month", days: 30 }
} as const;
const LEAGUE_PRODUCT = "private_league_create";
const MAX_BODY_BYTES = 16_384;
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
  if (![env.FIREBASE_IOS_APP_ID, env.FIREBASE_ANDROID_APP_ID].includes(appId)) {
    throw new HttpError(403, "La app no está autorizada.");
  }
  return { uid, appId };
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
      console.error("Apple transaction lookup failed", { status: response.status, environmentIndex: index });
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
  const key = await importPKCS8(normalizePrivateKey(env.GOOGLE_PRIVATE_KEY), "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore"
  })
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
    console.error("Google OAuth failed", { status: response.status });
    throw new HttpError(503, "No se pudo completar la entrega.");
  }
  const result = await response.json() as { access_token?: unknown };
  if (typeof result.access_token !== "string") throw new HttpError(503, "No se pudo completar la entrega.");
  return result.access_token;
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
    console.error("Firestore read failed", { status: response.status, path });
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

type FirestoreWrite = {
  update: { name: string; fields: Record<string, FirestoreValue> };
  updateMask?: { fieldPaths: string[] };
  currentDocument?: { exists?: boolean; updateTime?: string };
};

async function commit(env: Env, token: string, writes: FirestoreWrite[]): Promise<void> {
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
    console.error("Firestore commit failed", { status: response.status });
    throw new HttpError(response.status === 409 ? 409 : 503, "No se pudo completar la entrega.");
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
      if (url.pathname === "/v1/leagues/join") return joinLeague(request, auth, env);
      throw new HttpError(404, "Ruta no encontrada.");
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      if (error instanceof Error && ["JWTExpired", "JWSSignatureVerificationFailed", "JWTClaimValidationFailed"].includes(error.name)) {
        return json({ error: "Sesión o validación de app no válida." }, 401);
      }
      console.error("Unhandled request error", error instanceof Error ? { name: error.name, message: error.message } : "unknown");
      return json({ error: "Error temporal del servicio." }, 503);
    }
  }
} satisfies ExportedHandler<Env>;
