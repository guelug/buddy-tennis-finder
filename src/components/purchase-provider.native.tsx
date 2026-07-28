import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { PropsWithChildren } from "react";
import { Platform } from "react-native";
import { ErrorCode, useIAP } from "expo-iap";
// `ExpoPurchaseError` es el que entregan los callbacks del hook; el
// `PurchaseError` de la raíz declara `code` como obligatorio y no encaja.
import type { ExpoPurchaseError, Purchase } from "expo-iap";
import {
  COACH_PRODUCTS,
  PRIVATE_LEAGUE_PRODUCT
} from "@/lib/community";
import { AppErrorBoundary } from "@/components/app-error-boundary";
import { useAuth } from "@/lib/firebase-auth";
import { PURCHASES_ENABLED } from "@/lib/features";
import {
  loadPurchaseIntents,
  removePurchaseIntent,
  savePurchaseIntent,
  PURCHASE_PRODUCT_IDS,
  type PurchaseIntent,
  type PurchaseOutcome
} from "@/lib/purchase-intents";
import type { CoachAd, PrivateLeagueInput } from "@/types";
import { iapAccountTokenForUid } from "@/lib/iap-account-token";
import { verifyApplePurchase } from "@/lib/secure-backend";

export type { PurchaseOutcome } from "@/lib/purchase-intents";

type PurchaseContextValue = {
  connected: boolean;
  products: Array<{ id: string; displayPrice?: string }>;
  outcome: PurchaseOutcome | null;
  startCoachPurchase: (ad: CoachAd) => Promise<number>;
  startLeaguePurchase: (input: PrivateLeagueInput) => Promise<number>;
};

const PurchaseContext = createContext<PurchaseContextValue | null>(null);

/**
 * Si el módulo de facturación de Play falla en un dispositivo (billing no
 * disponible, servicio caído), las compras quedan desactivadas pero la app
 * sigue funcionando: nunca debe tumbar el arranque.
 */
export function PurchaseProvider({ children }: PropsWithChildren) {
  if (!PURCHASES_ENABLED) {
    return <UnavailablePurchaseProvider>{children}</UnavailablePurchaseProvider>;
  }

  return (
    <AppErrorBoundary fallback={<UnavailablePurchaseProvider>{children}</UnavailablePurchaseProvider>}>
      <ConnectedPurchaseProvider>{children}</ConnectedPurchaseProvider>
    </AppErrorBoundary>
  );
}

const purchasesUnavailable = async (): Promise<number> => {
  throw new Error("Las compras no están disponibles en este dispositivo ahora mismo.");
};

function UnavailablePurchaseProvider({ children }: PropsWithChildren) {
  return (
    <PurchaseContext.Provider
      value={{ connected: false, products: [], outcome: null, startCoachPurchase: purchasesUnavailable, startLeaguePurchase: purchasesUnavailable }}
    >
      {children}
    </PurchaseContext.Provider>
  );
}

function ConnectedPurchaseProvider({ children }: PropsWithChildren) {
  const { user } = useAuth();
  // expo-iap 4 sustituyó `currentPurchase`/`currentPurchaseError` por
  // callbacks; los reflejamos en estado para conservar el flujo por efectos.
  const [currentPurchase, setCurrentPurchase] = useState<Purchase | null>(null);
  const [currentPurchaseError, setCurrentPurchaseError] = useState<ExpoPurchaseError | null>(null);
  const { connected, products, fetchProducts, finishTransaction, getAvailablePurchases, availablePurchases, requestPurchase } = useIAP({
    onPurchaseSuccess: setCurrentPurchase,
    onPurchaseError: setCurrentPurchaseError
  });
  const [intents, setIntents] = useState<PurchaseIntent[]>([]);
  const [intentsLoaded, setIntentsLoaded] = useState(false);
  const [outcome, setOutcome] = useState<PurchaseOutcome | null>(null);
  const [activeProductId, setActiveProductId] = useState<string | null>(null);
  const processingTokens = useRef(new Set<string>());
  const handledPurchaseError = useRef<unknown>(null);

  useEffect(() => {
    setIntentsLoaded(false);
    setIntents([]);
    if (!user?.uid) return;
    let active = true;
    void loadPurchaseIntents(user.uid).then((stored) => {
      if (!active) return;
      setIntents(stored);
      setIntentsLoaded(true);
    });
    return () => { active = false; };
  }, [user?.uid]);

  useEffect(() => {
    if (!connected) return;
    void fetchProducts({ skus: [...PURCHASE_PRODUCT_IDS], type: "in-app" });
    void getAvailablePurchases();
  }, [connected, fetchProducts, getAvailablePurchases]);

  const forgetIntent = useCallback(async (ownerId: string, productId: string) => {
    await removePurchaseIntent(ownerId, productId);
    setIntents((current) => current.filter((item) => !(item.ownerId === ownerId && item.productId === productId)));
  }, []);

  const processRecoveredPurchase = useCallback(async (purchase: Purchase) => {
    const transactionId = purchase.transactionId;
    if (!transactionId || !user?.uid || processingTokens.current.has(transactionId)) return;
    const intent = intents.find((item) => item.ownerId === user.uid && item.productId === purchase.productId);
    if (!intent) return;
    processingTokens.current.add(transactionId);
    setOutcome({ kind: intent.kind, productId: intent.productId, status: "recovering", adId: intent.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent.createdAt, occurredAt: Date.now() });
    try {
      if (Platform.OS !== "ios") throw new Error("Las compras de Android todavía no están disponibles.");
      const verified = await verifyApplePurchase(intent, transactionId);
      await finishTransaction({ purchase, isConsumable: true });
      await forgetIntent(intent.ownerId, intent.productId);
      setOutcome(intent.kind === "coach"
        ? { kind: "coach", productId: intent.productId, status: "verified", adId: intent.adId, intentCreatedAt: intent.createdAt, occurredAt: Date.now() }
        : { kind: "league", productId: intent.productId, status: "verified", leagueId: verified.leagueId, intentCreatedAt: intent.createdAt, occurredAt: Date.now() });
      void getAvailablePurchases();
    } catch (error) {
      setOutcome({
        kind: intent.kind,
        productId: intent.productId,
        status: "error",
        adId: intent.kind === "coach" ? intent.adId : undefined,
        intentCreatedAt: intent.createdAt,
        message: error instanceof Error ? error.message : "La compra sigue pendiente de verificación.",
        occurredAt: Date.now()
      });
    } finally {
      processingTokens.current.delete(transactionId);
    }
  }, [user?.uid, intents, finishTransaction, forgetIntent, getAvailablePurchases]);

  useEffect(() => {
    if (!intentsLoaded) return;
    const purchases = [...availablePurchases, ...(currentPurchase ? [currentPurchase] : [])];
    const unique = new Map(purchases.map((item) => [
      item.purchaseToken,
      item
    ]).filter((entry): entry is [string, typeof purchases[number]] => Boolean(entry[0])));
    unique.forEach((purchase) => { void processRecoveredPurchase(purchase); });
  }, [intentsLoaded, intents, availablePurchases, currentPurchase, processRecoveredPurchase]);

  useEffect(() => {
    if (!currentPurchaseError || !user?.uid) return;
    if (handledPurchaseError.current === currentPurchaseError) return;
    handledPurchaseError.current = currentPurchaseError;
    const productId = currentPurchaseError.productId || activeProductId;
    if (!productId) return;
    const intent = intents.find((item) => item.productId === productId && item.ownerId === user.uid);
    if (currentPurchaseError.code === ErrorCode.AlreadyOwned) {
      setOutcome({ kind: productId === PRIVATE_LEAGUE_PRODUCT.id ? "league" : "coach", productId, status: "recovering", adId: intent?.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent?.createdAt, message: "Recuperando la compra anterior…", occurredAt: Date.now() });
      void getAvailablePurchases();
      return;
    }
    const kind = productId === PRIVATE_LEAGUE_PRODUCT.id ? "league" : "coach";
    void forgetIntent(user.uid, productId);
    setOutcome({ kind, productId, status: "error", adId: intent?.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent?.createdAt, message: currentPurchaseError.code === ErrorCode.UserCancelled ? "Compra cancelada." : currentPurchaseError.message, occurredAt: Date.now() });
  }, [currentPurchaseError, activeProductId, user?.uid, intents, forgetIntent, getAvailablePurchases]);

  const start = useCallback(async (intent: PurchaseIntent) => {
    if (!connected) throw new Error(`${Platform.OS === "ios" ? "App Store" : "Google Play"} no está disponible en este momento.`);
    await savePurchaseIntent(intent);
    setIntents((current) => [...current.filter((item) => item.productId !== intent.productId), intent]);
    setActiveProductId(intent.productId);
    setOutcome(null);
    try {
      if (Platform.OS !== "ios") throw new Error("Las compras de Android todavía no están disponibles.");
      const appAccountToken = await iapAccountTokenForUid(intent.ownerId);
      await requestPurchase({
        request: { apple: { sku: intent.productId, appAccountToken } },
        type: "in-app"
      });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === ErrorCode.AlreadyOwned) {
        void getAvailablePurchases();
        return intent.createdAt;
      }
      await forgetIntent(intent.ownerId, intent.productId);
      throw error;
    }
    return intent.createdAt;
  }, [connected, forgetIntent, getAvailablePurchases, requestPurchase]);

  const startCoachPurchase = useCallback(async (ad: CoachAd) => {
    if (!user?.uid || ad.ownerId !== user.uid) throw new Error("La sesión no coincide con el anuncio.");
    const productId = COACH_PRODUCTS[ad.plan].id;
    return start({ kind: "coach", ownerId: user.uid, productId, adId: ad.id, plan: ad.plan, createdAt: Date.now() });
  }, [user?.uid, start]);

  const startLeaguePurchase = useCallback(async (input: PrivateLeagueInput) => {
    if (!user?.uid) throw new Error("Inicia sesión para crear la liga.");
    return start({ kind: "league", ownerId: user.uid, productId: PRIVATE_LEAGUE_PRODUCT.id, input, createdAt: Date.now() });
  }, [user?.uid, start]);

  const value = useMemo<PurchaseContextValue>(() => ({ connected, products, outcome, startCoachPurchase, startLeaguePurchase }), [connected, products, outcome, startCoachPurchase, startLeaguePurchase]);
  return <PurchaseContext.Provider value={value}>{children}</PurchaseContext.Provider>;
}

export function usePurchases() {
  const value = useContext(PurchaseContext);
  if (!value) throw new Error("usePurchases debe usarse dentro de PurchaseProvider.");
  return value;
}
