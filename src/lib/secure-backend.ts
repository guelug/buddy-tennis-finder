import { getToken } from "@react-native-firebase/app-check";
import { auth, appCheckReady, ensureAppCheckReady } from "@/../firebase.config";
import { iapAccountTokenForUid } from "@/lib/iap-account-token";
import type { PurchaseIntent } from "@/lib/purchase-intents";

// Es una URL pública, no un secreto. El valor por defecto evita que Xcode
// Cloud genere una build con compras visibles pero sin verificador por no
// disponer del `.env` local.
const SECURE_BACKEND_URL = (
  process.env.EXPO_PUBLIC_SECURE_BACKEND_URL
  ?? "https://matchpoint-iap-verifier.guelug.workers.dev"
).replace(/\/+$/, "");
const REQUEST_TIMEOUT_MS = 25_000;
const ACCOUNT_DELETION_TIMEOUT_MS = 60_000;

type VerifyPurchaseResult = {
  verified: true;
  repeated: boolean;
  kind: "coach" | "league";
  adId?: string;
  leagueId?: string;
};

function backendUrl(path: string): string {
  if (!SECURE_BACKEND_URL?.startsWith("https://")) {
    throw new Error("El servicio seguro de compras no está configurado.");
  }
  return `${SECURE_BACKEND_URL}${path}`;
}

async function authenticatedPost<T>(path: string, body: unknown, timeoutMs = REQUEST_TIMEOUT_MS): Promise<T> {
  const user = auth.currentUser;
  if (!user) throw new Error("La sesión ha caducado.");
  await ensureAppCheckReady();
  const appCheck = await appCheckReady;
  if (!appCheck) throw new Error("No se pudo validar esta instalación.");

  const [idToken, appCheckToken] = await Promise.all([
    user.getIdToken(),
    getToken(appCheck)
  ]);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(backendUrl(path), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${idToken}`,
        "Content-Type": "application/json",
        "X-Firebase-AppCheck": appCheckToken.token
      },
      body: JSON.stringify(body),
      signal: controller.signal
    });
    const result = await response.json().catch(() => null) as { error?: unknown } | null;
    if (!response.ok) {
      throw new Error(typeof result?.error === "string" ? result.error : "El servicio seguro no pudo completar la operación.");
    }
    return result as T;
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") {
      throw new Error("La operación está tardando demasiado. Vuelve a intentarlo.");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

export async function verifyApplePurchase(
  intent: PurchaseIntent,
  transactionId: string
): Promise<VerifyPurchaseResult> {
  const appAccountToken = await iapAccountTokenForUid(intent.ownerId);
  const common = {
    kind: intent.kind,
    productId: intent.productId,
    transactionId,
    appAccountToken
  };
  return authenticatedPost<VerifyPurchaseResult>("/v1/apple/verify", intent.kind === "coach"
    ? { ...common, adId: intent.adId }
    : { ...common, league: intent.input });
}

export async function verifyAndroidPurchase(
  intent: PurchaseIntent,
  purchaseToken: string
): Promise<VerifyPurchaseResult> {
  const appAccountToken = await iapAccountTokenForUid(intent.ownerId);
  const common = {
    kind: intent.kind,
    productId: intent.productId,
    purchaseToken,
    appAccountToken
  };
  return authenticatedPost<VerifyPurchaseResult>("/v1/android/verify", intent.kind === "coach"
    ? { ...common, adId: intent.adId }
    : { ...common, league: intent.input });
}

export async function joinPrivateLeagueSecure(leagueId: string, inviteCode: string): Promise<void> {
  await authenticatedPost<{ joined: true }>("/v1/leagues/join", {
    leagueId,
    inviteCode: inviteCode.trim().toUpperCase()
  });
}

export async function deleteAccountSecure(): Promise<void> {
  await authenticatedPost<{ deleted: true }>("/v1/account/delete", {
    confirmation: "DELETE_ACCOUNT"
  }, ACCOUNT_DELETION_TIMEOUT_MS);
}
