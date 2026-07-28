import { Platform } from "react-native";
import { GoogleSignin } from "@react-native-google-signin/google-signin";
import {
  GOOGLE_IOS_CLIENT_ID,
  GOOGLE_WEB_CLIENT_ID
} from "@/lib/google-oauth-config";
import {
  requireGoogleAuthTokens,
  type GoogleAuthTokens
} from "@/lib/google-auth-tokens";

// Los identificadores OAuth son públicos y viven en código para que una build
// de Xcode Cloud/Gradle no dependa de `.env`. Un valor local antiguo ya no
// puede invalidar los tokens nativos.

const isConfigured =
  Boolean(GOOGLE_WEB_CLIENT_ID) &&
  (Platform.OS === "android" || Boolean(GOOGLE_IOS_CLIENT_ID));

if (isConfigured) {
  GoogleSignin.configure({
    webClientId: GOOGLE_WEB_CLIENT_ID,
    iosClientId: GOOGLE_IOS_CLIENT_ID || undefined,
    offlineAccess: false,
    forceCodeForRefreshToken: false
  });
}

export function isNativeGoogleSignInConfigured(): boolean {
  return isConfigured;
}

export async function requestNativeGoogleTokens(): Promise<GoogleAuthTokens | null> {
  if (!isConfigured) {
    throw new Error("Google Sign-In nativo todavía no está configurado.");
  }

  await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
  const response = await GoogleSignin.signIn();

  if (response.type !== "success") return null;
  const tokens = await GoogleSignin.getTokens();

  return requireGoogleAuthTokens({
    idToken: response.data.idToken ?? tokens.idToken,
    accessToken: tokens.accessToken
  });
}

export async function signOutFromGoogleNative(): Promise<void> {
  if (!isConfigured) return;
  await GoogleSignin.signOut();
}
