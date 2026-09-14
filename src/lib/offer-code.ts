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
  return Platform.OS === "ios" && native != null;
}

/** Presents StoreKit's sheet; purchases are verified separately by the backend. */
export async function presentOfferCodeRedeemSheet(): Promise<OfferCodeRedemption> {
  if (!native?.presentOfferCodeRedeemSheet) {
    throw new Error("Los códigos promocionales de App Store solo están disponibles en iOS.");
  }
  return native.presentOfferCodeRedeemSheet();
}
