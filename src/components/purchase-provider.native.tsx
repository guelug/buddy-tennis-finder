import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { PropsWithChildren } from "react";
import * as Crypto from "expo-crypto";
import { requestPurchase, useIAP } from "expo-iap";
import {
  COACH_PRODUCTS,
  PRIVATE_LEAGUE_PRODUCT,
  registerCoachPurchase,
  registerLeaguePurchase,
  waitForCoachPurchaseVerification,
  waitForLeaguePurchaseVerification
} from "@/lib/community";
import { AppErrorBoundary } from "@/components/app-error-boundary";
import { useAuth } from "@/lib/firebase-auth";
import {
  loadPurchaseIntents,
  removePurchaseIntent,
  savePurchaseIntent,
  PURCHASE_PRODUCT_IDS,
  type PurchaseIntent,
  type PurchaseOutcome
} from "@/lib/purchase-intents";
import type { CoachAd, PrivateLeagueInput } from "@/types";

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
  const { connected, products, getProducts, getAvailablePurchases, availablePurchases, currentPurchase, currentPurchaseError } = useIAP();
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
    void getProducts([...PURCHASE_PRODUCT_IDS]);
    void getAvailablePurchases([...PURCHASE_PRODUCT_IDS]);
  }, [connected, getProducts, getAvailablePurchases]);

  const forgetIntent = useCallback(async (ownerId: string, productId: string) => {
    await removePurchaseIntent(ownerId, productId);
    setIntents((current) => current.filter((item) => !(item.ownerId === ownerId && item.productId === productId)));
  }, []);

  const processRecoveredPurchase = useCallback(async (purchase: NonNullable<typeof currentPurchase>) => {
    const token = purchase.purchaseToken;
    if (!token || !user?.uid || processingTokens.current.has(token)) return;
    const intent = intents.find((item) => item.ownerId === user.uid && item.productId === purchase.id);
    if (!intent) return;
    processingTokens.current.add(token);
    setOutcome({ kind: intent.kind, productId: intent.productId, status: "recovering", adId: intent.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent.createdAt, occurredAt: Date.now() });
    try {
      if (intent.kind === "coach") {
        await registerCoachPurchase(intent.adId, intent.productId, token, purchase.transactionId);
        await waitForCoachPurchaseVerification(token);
        await forgetIntent(intent.ownerId, intent.productId);
        setOutcome({ kind: "coach", productId: intent.productId, status: "verified", adId: intent.adId, intentCreatedAt: intent.createdAt, occurredAt: Date.now() });
      } else {
        await registerLeaguePurchase(intent.input, token, purchase.transactionId);
        const leagueId = await waitForLeaguePurchaseVerification(token);
        await forgetIntent(intent.ownerId, intent.productId);
        setOutcome({ kind: "league", productId: intent.productId, status: "verified", leagueId, intentCreatedAt: intent.createdAt, occurredAt: Date.now() });
      }
      // El backend consume el producto. Refrescamos la caché de Billing para
      // que pueda volver a comprarse una nueva publicación o liga.
      void getAvailablePurchases([...PURCHASE_PRODUCT_IDS]);
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
      processingTokens.current.delete(token);
    }
  }, [user?.uid, intents, forgetIntent, getAvailablePurchases]);

  useEffect(() => {
    if (!intentsLoaded) return;
    const purchases = [...availablePurchases, ...(currentPurchase ? [currentPurchase] : [])];
    const unique = new Map(purchases.filter((item) => item.purchaseToken).map((item) => [item.purchaseToken as string, item]));
    unique.forEach((purchase) => { void processRecoveredPurchase(purchase); });
  }, [intentsLoaded, intents, availablePurchases, currentPurchase, processRecoveredPurchase]);

  useEffect(() => {
    if (!currentPurchaseError || !user?.uid) return;
    if (handledPurchaseError.current === currentPurchaseError) return;
    handledPurchaseError.current = currentPurchaseError;
    const productId = currentPurchaseError.productId || activeProductId;
    if (!productId) return;
    const intent = intents.find((item) => item.productId === productId && item.ownerId === user.uid);
    if (currentPurchaseError.code === "E_ALREADY_OWNED") {
      setOutcome({ kind: productId === PRIVATE_LEAGUE_PRODUCT.id ? "league" : "coach", productId, status: "recovering", adId: intent?.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent?.createdAt, message: "Recuperando la compra anterior…", occurredAt: Date.now() });
      void getAvailablePurchases([...PURCHASE_PRODUCT_IDS]);
      return;
    }
    const kind = productId === PRIVATE_LEAGUE_PRODUCT.id ? "league" : "coach";
    void forgetIntent(user.uid, productId);
    setOutcome({ kind, productId, status: "error", adId: intent?.kind === "coach" ? intent.adId : undefined, intentCreatedAt: intent?.createdAt, message: currentPurchaseError.code === "E_USER_CANCELLED" ? "Compra cancelada." : currentPurchaseError.message, occurredAt: Date.now() });
  }, [currentPurchaseError, activeProductId, user?.uid, intents, forgetIntent, getAvailablePurchases]);

  const start = useCallback(async (intent: PurchaseIntent) => {
    if (!connected) throw new Error("Google Play no está disponible en este momento.");
    await savePurchaseIntent(intent);
    setIntents((current) => [...current.filter((item) => item.productId !== intent.productId), intent]);
    setActiveProductId(intent.productId);
    setOutcome(null);
    const accountHash = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, intent.ownerId);
    try {
      await requestPurchase({
        request: {
          ios: { sku: intent.productId },
          android: { skus: [intent.productId], obfuscatedAccountIdAndroid: accountHash }
        },
        type: "inapp"
      });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === "E_ALREADY_OWNED") {
        void getAvailablePurchases([...PURCHASE_PRODUCT_IDS]);
        return intent.createdAt;
      }
      await forgetIntent(intent.ownerId, intent.productId);
      throw error;
    }
    return intent.createdAt;
  }, [connected, forgetIntent, getAvailablePurchases]);

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
