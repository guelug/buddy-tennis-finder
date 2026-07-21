import { initializeApp, getApps, getApp, type FirebaseApp } from "firebase/app";
import type { Auth } from "firebase/auth";
import { getFirestore, initializeFirestore, type Firestore } from "firebase/firestore";
import { Platform } from "react-native";
import { configureAppCheck } from "@/lib/configure-app-check";
import { createFirebaseAuth } from "@/lib/create-firebase-auth";

/**
 * Inicialización de Firebase desde variables de entorno públicas (prefijo EXPO_PUBLIC_).
 * Estas variables se incrustan en el bundle en tiempo de build (según documentación de Expo):
 * https://docs.expo.dev/build-reference/variables/
 *
 * En desarrollo local, crea un archivo `.env` con los valores de tu proyecto Firebase.
 *
 * IMPORTANTE: Auth y Firestore se inicializan solo si las variables existen. Si faltan,
 * auth/db quedan como `null` (con cast de tipo para no romper los call sites, que siempre
 * chequean `isFirebaseConfigured` antes de usarlos). Esto evita que `getAuth` lance
 * `auth/invalid-api-key` durante el render estático en web cuando todavía no hay .env.
 */
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID
};

function hasConfigValue(value: string | undefined) {
  return !!value && value !== "undefined" && value !== "null";
}

const missingKeys = (Object.keys(firebaseConfig) as Array<keyof typeof firebaseConfig>).filter(
  (key) => !hasConfigValue(firebaseConfig[key])
);

export const isFirebaseConfigured = missingKeys.length === 0;

if (!isFirebaseConfigured) {
  console.warn(
    `[matchpoint] Faltan variables de Firebase: ${missingKeys.join(", ")}. ` +
      "Crea el archivo .env con EXPO_PUBLIC_FIREBASE_* (ver .env.example). " +
      "La app correrá en modo demo con datos semilla."
  );
}

// App: la inicializamos siempre (no falla sin config), pero Auth/DB solo si hay config.
const app: FirebaseApp = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

export const auth: Auth = isFirebaseConfigured ? createFirebaseAuth(app) : (null as unknown as Auth);
/**
 * En nativo, el transporte WebChannel de Firestore se cuelga en algunas redes
 * y dispositivos Android (la app "no responde" al cargar datos). El
 * auto-detect de long-polling cambia de transporte cuando detecta el problema.
 */
function createFirestore(firebaseApp: FirebaseApp): Firestore {
  if (Platform.OS === "web") return getFirestore(firebaseApp);
  try {
    return initializeFirestore(firebaseApp, { experimentalAutoDetectLongPolling: true });
  } catch {
    // Fast Refresh: Firestore ya inicializado.
    return getFirestore(firebaseApp);
  }
}

export const db: Firestore = isFirebaseConfigured ? createFirestore(app) : (null as unknown as Firestore);

/**
 * App Check (anti-bot) — protege Auth y Firestore contra tráfico automatizado
 * (registros masivos, scraping) verificando que las peticiones vengan de esta
 * app real, no de un script.
 *
 * Solo se activa en web y solo si hay una site key de reCAPTCHA v3 configurada
 * (EXPO_PUBLIC_RECAPTCHA_SITE_KEY). El require del SDK es condicional a
 * propósito: `firebase/app-check` toca APIs de navegador al cargarse, y
 * cargarlo siempre (import estático) se evalúa incluso durante el prerender
 * estático de Expo (`expo export`), donde no hay `window`/`indexedDB` — eso
 * colgaba el arranque de la app en producción aunque la key nunca llegara a
 * usarse. Con require() dentro del if, el módulo solo se evalúa si hay key.
 *
 * En iOS/Android nativo, App Check usa otros providers (App Attest / Play
 * Integrity). La separación por archivos de plataforma evita incluir el SDK
 * reCAPTCHA del navegador dentro del bundle nativo.
 */
const recaptchaSiteKey = process.env.EXPO_PUBLIC_RECAPTCHA_SITE_KEY;
if (isFirebaseConfigured && hasConfigValue(recaptchaSiteKey)) {
  configureAppCheck(app, recaptchaSiteKey);
}

export default app;
