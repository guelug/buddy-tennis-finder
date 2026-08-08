/** Web/test fallback. The native implementation lives in `ads.native.ts`. */
export const ADS_SUPPORTED = false;

export function nativeAdUnitId(): string {
  return "";
}

export function isUnderAgeOfConsent(age?: number): boolean {
  return typeof age !== "number" || age < 16;
}

export function startAds(_age?: number): Promise<boolean> {
  return Promise.resolve(false);
}

export function adsPrivacyOptionsRequired(): Promise<boolean> {
  return Promise.resolve(false);
}

export function showAdsPrivacyOptions(): Promise<boolean> {
  return Promise.resolve(false);
}

export function subscribeAdsConsentChanges(_listener: () => void): () => void {
  return () => {};
}
