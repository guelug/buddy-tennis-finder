import type { GoogleAuthTokens } from "@/lib/google-auth-tokens";

export function isNativeGoogleSignInConfigured(): boolean {
  return false;
}

export async function requestNativeGoogleTokens(): Promise<GoogleAuthTokens | null> {
  throw new Error("Google Sign-In nativo no está disponible en esta plataforma.");
}

export async function signOutFromGoogleNative(): Promise<void> {
  // Web usa el proveedor de Firebase y no mantiene una sesión nativa separada.
}
