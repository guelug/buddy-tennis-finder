import { useEffect, useState, useCallback, createContext, useContext, useMemo, type ReactNode } from "react";
import { Platform } from "react-native";
import * as AppleAuthentication from "expo-apple-authentication";
import * as Crypto from "expo-crypto";
import {
  GoogleAuthProvider,
  OAuthProvider,
  signInWithCredential,
  signOut as firebaseSignOut,
  onIdTokenChanged,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  updateProfile,
  type User as FirebaseUser
} from "@react-native-firebase/auth";
import { doc, serverTimestamp, setDoc } from "@react-native-firebase/firestore";
import { auth, db, isFirebaseConfigured } from "@/../firebase.config";
import { setCrashReportingUser } from "@/lib/crash-reporting";
import { getDeviceHash } from "@/lib/device-identity";
import {
  isNativeGoogleSignInConfigured,
  requestNativeGoogleIdToken,
  signOutFromGoogleNative
} from "@/lib/google-native-sign-in";
import { AuthUser } from "@/types";

/**
 * Traduce el usuario de Firebase Auth al modelo AuthUser de la app.
 */
function mapFirebaseUser(user: FirebaseUser | null): AuthUser | null {
  if (!user) return null;

  const providerId =
    (user.providerData?.[0]?.providerId as AuthUser["providerId"] | undefined) ??
    ("anonymous" as const);

  return {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoURL: user.photoURL,
    emailVerified: user.emailVerified,
    providerId
  };
}

async function syncPrivateIdentity(user: FirebaseUser) {
  const email = user.email?.trim().toLowerCase() ?? null;
  // La huella del dispositivo permite que las reglas rechacen una valoración
  // entre dos cuentas del mismo móvil. Es opcional: si no se puede calcular,
  // no bloqueamos el acceso.
  const deviceHash = await getDeviceHash();
  await setDoc(doc(db, "users", user.uid), {
    email,
    displayName: user.displayName?.trim() ?? null,
    providers: user.providerData.map((provider) => provider.providerId),
    emailVerified: user.emailVerified,
    ...(deviceHash ? { deviceHash } : {}),
    updatedAt: serverTimestamp()
  }, { merge: true });
}

// ----------------------------------------------------------------------------
// Google Sign In: selector de cuenta nativo en Android/iOS y popup en web.
// ----------------------------------------------------------------------------
export function isNativeGoogleAuthConfigured(): boolean {
  return Platform.OS !== "web" && isNativeGoogleSignInConfigured();
}

export async function signInWithGoogle(idToken: string, accessToken?: string) {
  const credential = GoogleAuthProvider.credential(idToken, accessToken);
  return signInWithCredential(auth, credential);
}

export async function signInWithGoogleNative() {
  if (Platform.OS === "web") {
    throw new Error("Este flujo solo está disponible en Android y iOS.");
  }
  const idToken = await requestNativeGoogleIdToken();
  if (!idToken) return null;
  return signInWithGoogle(idToken);
}

export async function signInWithGooglePopup() {
  throw new Error("El acceso web se ha retirado. Descarga la app de MatchPoint.");
}

// ----------------------------------------------------------------------------
// Email + contraseña (funciona en iOS, Android y web sin configuración extra)
// ----------------------------------------------------------------------------
function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export async function signUpWithEmail(email: string, password: string, displayName?: string) {
  const result = await createUserWithEmailAndPassword(auth, normalizeEmail(email), password);
  if (displayName?.trim()) {
    await updateProfile(result.user, { displayName: displayName.trim() });
  }
  // Sin este correo la cuenta se queda con `emailVerified: false` para
  // siempre y las reglas de Firestore le niegan el listado de jugadores
  // (`hasVerifiedIdentity`), así que la app entera se quedaba inservible
  // para quien se registrase con email. No bloqueamos el alta si falla.
  try {
    await sendEmailVerification(result.user);
  } catch (error) {
    console.warn("[matchpoint] no se pudo enviar el correo de verificación", error);
  }
  return result;
}

/** Reenvía el correo de verificación a la sesión actual. */
export async function resendVerificationEmail() {
  const current = auth.currentUser;
  if (!current) throw new Error("No hay sesión activa.");
  if (current.emailVerified) return false;
  await sendEmailVerification(current);
  return true;
}

export async function signInWithEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, normalizeEmail(email), password);
}

export async function resetPassword(email: string) {
  return sendPasswordResetEmail(auth, normalizeEmail(email));
}

/** Traduce los códigos de error de Firebase Auth a mensajes en español. */
export function describeAuthError(error: unknown): string {
  const code = (error as { code?: string })?.code ?? "";
  const messages: Record<string, string> = {
    "auth/invalid-email": "Ese correo no parece válido.",
    "auth/missing-password": "Escribe una contraseña.",
    "auth/weak-password": "La contraseña debe tener al menos 6 caracteres.",
    "auth/email-already-in-use": "Ya existe una cuenta con ese correo. Prueba a iniciar sesión.",
    "auth/invalid-credential": "Correo o contraseña incorrectos.",
    "auth/wrong-password": "Correo o contraseña incorrectos.",
    "auth/user-not-found": "No encontramos una cuenta con ese correo.",
    "auth/too-many-requests": "Demasiados intentos. Espera un momento y vuelve a intentar.",
    "auth/network-request-failed": "Sin conexión. Revisa tu internet e intenta de nuevo.",
    "PLAY_SERVICES_NOT_AVAILABLE": "Google Play Services no está disponible o necesita actualizarse.",
    "IN_PROGRESS": "Ya hay un inicio de sesión con Google en curso."
  };
  if (messages[code]) return messages[code];
  return error instanceof Error ? error.message : "Intenta de nuevo en unos momentos.";
}

// ----------------------------------------------------------------------------
// Apple Sign In (requiere build nativo en iOS, no Expo Go)
// ----------------------------------------------------------------------------
export async function signInWithApple() {
  if (Platform.OS !== "ios") {
    throw new Error("Apple Sign In solo está disponible en iOS.");
  }

  const rawNonce = Array.from(Crypto.getRandomBytes(32), (byte) => byte.toString(16).padStart(2, "0")).join("");
  const hashedNonce = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, rawNonce);

  const appleCredential = await AppleAuthentication.signInAsync({
    requestedScopes: [
      AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
      AppleAuthentication.AppleAuthenticationScope.EMAIL
    ],
    nonce: hashedNonce
  });

  if (!appleCredential.identityToken) {
    throw new Error("Apple no devolvió una credencial de identidad válida.");
  }

  const provider = new OAuthProvider("apple.com");
  const credential = provider.credential({
    idToken: appleCredential.identityToken,
    rawNonce
  });

  // Firebase administra la sesión y su refresh token. El authorizationCode
  // de Apple es de un solo uso y no debe guardarse como si fuera un refresh
  // token; además, un fallo de Keychain después de autenticar hacía que la UI
  // mostrase un error aunque la sesión ya se hubiese creado correctamente.
  return signInWithCredential(auth, credential);
}

export async function signOut() {
  await signOutFromGoogleNative().catch(() => undefined);
  await firebaseSignOut(auth);
}

// ----------------------------------------------------------------------------
// Hook de autenticación (con React Context para evitar N suscripciones)
// ----------------------------------------------------------------------------
type AuthContextValue = {
  user: AuthUser | null;
  loading: boolean;
  isConfigured: boolean;
  refreshIdToken: () => Promise<string | null>;
};

const AuthContext = createContext<AuthContextValue>({
  user: null,
  loading: true,
  isConfigured: false,
  refreshIdToken: async () => null
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isFirebaseConfigured) {
      setLoading(false);
      return;
    }

    // onIdTokenChanged cubre login, logout y renovación de token.
    const unsubscribe = onIdTokenChanged(auth, (firebaseUser) => {
      setUser(mapFirebaseUser(firebaseUser));
      setLoading(false);
      setCrashReportingUser(firebaseUser?.uid ?? null);
      if (firebaseUser) syncPrivateIdentity(firebaseUser).catch((error) => console.warn("[matchpoint] identity sync", error));
    });

    return unsubscribe;
  }, []);

  const refreshIdToken = useCallback(async () => {
    const currentUser = auth.currentUser;
    if (!currentUser) return null;
    return currentUser.getIdToken(true);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ user, loading, isConfigured: isFirebaseConfigured, refreshIdToken }),
    [user, loading, refreshIdToken]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
