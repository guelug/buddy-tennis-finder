import { createContext, useContext } from "react";
import type { PropsWithChildren } from "react";
import type { PurchaseOutcome } from "@/lib/purchase-intents";
import type { CoachAd, PrivateLeagueInput } from "@/types";

export type { PurchaseOutcome } from "@/lib/purchase-intents";

type PurchaseContextValue = {
  connected: boolean;
  products: Array<{ id: string; displayPrice?: string }>;
  outcome: PurchaseOutcome | null;
  startCoachPurchase: (ad: CoachAd) => Promise<number>;
  startLeaguePurchase: (input: PrivateLeagueInput) => Promise<number>;
};

const unavailable = async (): Promise<number> => { throw new Error("Las compras están disponibles en la app móvil de MatchPoint."); };
const PurchaseContext = createContext<PurchaseContextValue>({
  connected: false,
  products: [],
  outcome: null,
  startCoachPurchase: unavailable,
  startLeaguePurchase: unavailable
});

export function PurchaseProvider({ children }: PropsWithChildren) {
  return <PurchaseContext.Provider value={{ connected: false, products: [], outcome: null, startCoachPurchase: unavailable, startLeaguePurchase: unavailable }}>{children}</PurchaseContext.Provider>;
}

export function usePurchases() {
  return useContext(PurchaseContext);
}
