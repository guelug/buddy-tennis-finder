import * as Device from "expo-device";
import { Platform } from "react-native";
import { getApp } from "@react-native-firebase/app";
import { getAuth, type Auth } from "@react-native-firebase/auth";
import { getFirestore, type Firestore } from "@react-native-firebase/firestore";
import {
  ReactNativeFirebaseAppCheckProvider,
  initializeAppCheck,
  type AppCheck
} from "@react-native-firebase/app-check";

/**
 * Firebase nativo lee GoogleService-Info.plist y google-services.json. Ya no
 * se incluyen credenciales ni SDK de Firebase en la landing pública.
 */
const app = getApp();

// Firebase App Check está exigido en el proyecto. Un simulador no puede
// generar App Attest/Play Integrity, así que lo tratamos como entorno demo
// (sin peticiones autenticadas) y dejamos Firebase activo en web y en
// dispositivos físicos.
const firebaseCanAuthenticate = Platform.OS === "web" || Device.isDevice === true;
export const isFirebaseConfigured = firebaseCanAuthenticate;

// App Attest y Play Integrity requieren un dispositivo físico real. En
// simulador, App Attest no tiene Secure Enclave y falla; el provider debug
// requiere registrar el token manualmente en Firebase Console. Para no
// bloquear el desarrollo ni las capturas de store en simulador, simplemente
// no inicializamos App Check cuando no es un dispositivo real.
// `Constants.isDevice` quedó obsoleto en Expo SDK 57 y en algunos builds de
// iOS devuelve `true` también en el simulador. `expo-device` expone la señal
// nativa correcta y evita que App Check intente usar App Attest/debug tokens
// sin Secure Enclave.
const isRealDevice = Device.isDevice === true;

export const appCheckReady: Promise<AppCheck | null> = isRealDevice
  ? (() => {
      const provider = new ReactNativeFirebaseAppCheckProvider();
      provider.configure({
        android: { provider: __DEV__ ? "debug" : "playIntegrity" },
        // App Attest cuando está disponible; DeviceCheck mantiene el acceso
        // en dispositivos donde App Attest no puede emitir una atestación.
        apple: { provider: __DEV__ ? "debug" : "appAttestWithDeviceCheckFallback" }
      });
      return initializeAppCheck(app, {
        provider,
        isTokenAutoRefreshEnabled: true
      }).catch((error: unknown) => {
        console.warn("[matchpoint] App Check no pudo inicializarse", error);
        return null;
      });
    })()
  : Promise.resolve(null);

export const auth: Auth = getAuth(app);
export const db: Firestore = getFirestore(app);

export async function ensureAppCheckReady(): Promise<void> {
  if (!isRealDevice) return;
  await appCheckReady;
}

export default app;
