import { Platform } from "react-native";
import { GoogleSignin } from "@react-native-google-signin/google-signin";

const GOOGLE_WEB_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
const GOOGLE_IOS_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID;

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

export async function requestNativeGoogleIdToken(): Promise<string | null> {
  if (!isConfigured) {
    throw new Error("Google Sign-In nativo todavía no está configurado.");
  }

  await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
  const response = await GoogleSignin.signIn();

  if (response.type !== "success") return null;
  if (!response.data.idToken) {
    throw new Error("Google no devolvió un token de identidad válido.");
  }

  return response.data.idToken;
}

export async function signOutFromGoogleNative(): Promise<void> {
  if (!isConfigured) return;
  await GoogleSignin.signOut();
}
