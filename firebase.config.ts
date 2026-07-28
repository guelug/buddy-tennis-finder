import { getApp } from "@react-native-firebase/app";
import { getAuth, type Auth } from "@react-native-firebase/auth";
import { getFirestore, type Firestore } from "@react-native-firebase/firestore";
import {
  ReactNativeFirebaseAppCheckProvider,
  initializeAppCheck
} from "@react-native-firebase/app-check";

/**
 * Firebase nativo lee GoogleService-Info.plist y google-services.json. Ya no
 * se incluyen credenciales ni SDK de Firebase en la landing pública.
 */
const app = getApp();

export const isFirebaseConfigured = true;

const provider = new ReactNativeFirebaseAppCheckProvider();
provider.configure({
  android: {
    provider: __DEV__ ? "debug" : "playIntegrity"
  },
  apple: {
    provider: __DEV__ ? "debug" : "appAttest"
  }
});

/**
 * Se inicia al cargar el módulo, antes de que Auth o Firestore hagan su
 * primera petición. En desarrollo el token de depuración aparece en la
 * consola y debe registrarse en Firebase; las releases usan attestation real.
 */
export const appCheckReady = initializeAppCheck(app, {
  provider,
  isTokenAutoRefreshEnabled: true
}).catch((error: unknown) => {
  console.warn("[matchpoint] App Check no pudo inicializarse", error);
  return null;
});

// App Check debe registrarse antes de construir Auth y Firestore. De lo
// contrario, una primera petición muy rápida puede salir sin token justo
// después de abrir la app y Firebase la rechaza cuando enforcement está activo.
export const auth: Auth = getAuth(app);
export const db: Firestore = getFirestore(app);

export async function ensureAppCheckReady(): Promise<void> {
  await appCheckReady;
}

export default app;
