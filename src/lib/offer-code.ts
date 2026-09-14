import { Platform } from "react-native";
import { requireOptionalNativeModule } from "expo-modules-core";

export type OfferCodeRedemption = {
  verified?: boolean;
  presented?: boolean;
  productId?: string;
  transactionId?: string;
};

type MatchPointOfferCodeNative = {
  presentOfferCodeRedeemSheet(): Promise<OfferCodeRedemption>;
};

const native = requireOptionalNativeModule<MatchPointOfferCodeNative>("MatchPointLocalAI");

export function canPresentOfferCode(): boolean {
  // The current sheet cannot bind appAccountToken to a new redemption.
  // The backend correctly rejects unbound transactions. Do not offer a flow
  // that can consume a code without delivering the product; keep normal IAP.
  return false;
}

/** Presents StoreKit's sheet; purchases are verified separately by the backend. */
export async function presentOfferCodeRedeemSheet(): Promise<OfferCodeRedemption> {
  if (!canPresentOfferCode() || Platform.OS !== "ios" || !native?.presentOfferCodeRedeemSheet) {
    throw new Error("Los códigos promocionales de App Store solo están disponibles en iOS.");
  }
  return native.presentOfferCodeRedeemSheet();
}
