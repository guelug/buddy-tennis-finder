import AsyncStorage from "@react-native-async-storage/async-storage";
import { COACH_PRODUCTS, PRIVATE_LEAGUE_PRODUCT } from "@/lib/community";
import type { CoachAd, PrivateLeagueInput } from "@/types";

export type CoachPurchaseIntent = {
  kind: "coach";
  ownerId: string;
  productId: string;
  adId: string;
  plan: CoachAd["plan"];
  createdAt: number;
};

export type LeaguePurchaseIntent = {
  kind: "league";
  ownerId: string;
  productId: typeof PRIVATE_LEAGUE_PRODUCT.id;
  input: PrivateLeagueInput;
  createdAt: number;
};

export type PurchaseIntent = CoachPurchaseIntent | LeaguePurchaseIntent;

export type PurchaseOutcome = {
  kind: "coach" | "league";
  productId: string;
  status: "verified" | "error" | "recovering";
  adId?: string;
  leagueId?: string;
  intentCreatedAt?: number;
  message?: string;
  occurredAt: number;
};

export const PURCHASE_PRODUCT_IDS = [
  COACH_PRODUCTS.week.id,
  COACH_PRODUCTS.month.id,
  PRIVATE_LEAGUE_PRODUCT.id
] as const;

function storageKey(ownerId: string, productId: string) {
  return `@matchpoint/purchase-intent/v1/${ownerId}/${productId}`;
}

export async function savePurchaseIntent(intent: PurchaseIntent) {
  await AsyncStorage.setItem(storageKey(intent.ownerId, intent.productId), JSON.stringify(intent));
}

export async function removePurchaseIntent(ownerId: string, productId: string) {
  await AsyncStorage.removeItem(storageKey(ownerId, productId));
}

export async function loadPurchaseIntents(ownerId: string): Promise<PurchaseIntent[]> {
  const pairs = await AsyncStorage.multiGet(PURCHASE_PRODUCT_IDS.map((productId) => storageKey(ownerId, productId)));
  const intents: PurchaseIntent[] = [];
  for (const [, raw] of pairs) {
    if (!raw) continue;
    try {
      const value = JSON.parse(raw) as Partial<PurchaseIntent>;
      if (value.ownerId === ownerId && typeof value.productId === "string" && (value.kind === "coach" || value.kind === "league")) {
        intents.push(value as PurchaseIntent);
      }
    } catch {
      // Un valor local dañado no debe impedir abrir la app ni recuperar otros pagos.
    }
  }
  return intents;
}
