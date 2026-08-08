import { Platform } from "react-native";
import mobileAds, {
  AgeRestrictedTreatment,
  AdsConsent,
  AdsConsentPrivacyOptionsRequirementStatus,
  MaxAdContentRating,
  TestIds
} from "react-native-google-mobile-ads";

const NATIVE_UNIT_IDS = {
  ios: "ca-app-pub-6613881091306161/6989997449",
  android: "ca-app-pub-6613881091306161/2330511792"
} as const;

export function nativeAdUnitId(): string {
  if (__DEV__) return TestIds.NATIVE;
  if (Platform.OS === "ios") return NATIVE_UNIT_IDS.ios;
  if (Platform.OS === "android") return NATIVE_UNIT_IDS.android;
  return TestIds.NATIVE;
}

export const ADS_SUPPORTED = Platform.OS === "ios" || Platform.OS === "android";

/**
 * The app accepts users from age 13. We use the highest EEA digital-consent
 * threshold (16) as a conservative rule for mixed-country profiles. This
 * prevents the UMP form and personalised advertising for ages 13–15.
 */
export function isUnderAgeOfConsent(age?: number): boolean {
  return typeof age !== "number" || age < 16;
}

function ageTreatment(age: number): AgeRestrictedTreatment {
  if (age < 16) return AgeRestrictedTreatment.CHILD;
  if (age < 18) return AgeRestrictedTreatment.TEEN;
  return AgeRestrictedTreatment.UNSPECIFIED;
}

let started: Promise<boolean> | null = null;
let startedForTreatment: string | null = null;
let consentRevision = 0;
const consentListeners = new Set<() => void>();

function notifyConsentChanged() {
  consentRevision += 1;
  consentListeners.forEach((listener) => listener());
}

export function subscribeAdsConsentChanges(listener: () => void): () => void {
  consentListeners.add(listener);
  return () => consentListeners.delete(listener);
}

async function initializeAds(age?: number): Promise<boolean> {
  if (typeof age !== "number") return false;
  const underAge = isUnderAgeOfConsent(age);

  try {
    await AdsConsent.gatherConsent({ tagForUnderAgeOfConsent: underAge });
  } catch {
    // UMP may be temporarily unavailable. Its SDK can still use a valid
    // decision from a previous launch, which we check below.
  }

  const consent = await AdsConsent.getConsentInfo().catch(() => null);
  if (!consent?.canRequestAds) return false;

  await mobileAds().setRequestConfiguration({
    maxAdContentRating: MaxAdContentRating.T,
    ageRestrictedTreatment: ageTreatment(age),
    // Keep TFUA while RN Google Mobile Ads 16.4 bridges the new enum
    // inconsistently on Android. Google applies the most conservative signal.
    tagForUnderAgeOfConsent: underAge
  });
  await mobileAds().initialize();
  return true;
}

/** Starts Google Mobile Ads once, after UMP has resolved for the profile age. */
export function startAds(age?: number): Promise<boolean> {
  if (!ADS_SUPPORTED) return Promise.resolve(false);
  if (typeof age !== "number") return Promise.resolve(false);
  const treatment = `${ageTreatment(age)}:${isUnderAgeOfConsent(age)}`;
  if (started && startedForTreatment === treatment) return started;

  startedForTreatment = treatment;
  started = initializeAds(age)
    .then((ready) => {
      if (!ready) {
        started = null;
        startedForTreatment = null;
      }
      return ready;
    })
    .catch(() => {
      started = null;
      startedForTreatment = null;
      return false;
    });
  return started;
}

export async function adsPrivacyOptionsRequired(): Promise<boolean> {
  if (!ADS_SUPPORTED) return false;
  const info = await AdsConsent.getConsentInfo();
  return info.privacyOptionsRequirementStatus === AdsConsentPrivacyOptionsRequirementStatus.REQUIRED;
}

/** Reopens Google's certified privacy-options form when regulation requires it. */
export async function showAdsPrivacyOptions(): Promise<boolean> {
  if (!(await adsPrivacyOptionsRequired())) return false;
  await AdsConsent.showPrivacyOptionsForm();
  started = null;
  startedForTreatment = null;
  notifyConsentChanged();
  return true;
}
