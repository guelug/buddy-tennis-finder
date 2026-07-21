import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  getAuth,
  initializeAuth,
  type Auth,
  type Persistence
} from "firebase/auth";
import type { FirebaseApp } from "firebase/app";

// Firebase expone esta API mediante su condición `react-native`, pero sus tipos
// genéricos no la declaran cuando tsc se ejecuta fuera de Metro.
const { getReactNativePersistence } = require("firebase/auth") as {
  getReactNativePersistence: (storage: typeof AsyncStorage) => Persistence;
};

/**
 * En Android/iOS Firebase necesita una persistencia React Native explícita.
 * Sin ella la sesión solo vive en memoria y se pierde al cerrar la app.
 */
export function createFirebaseAuth(app: FirebaseApp): Auth {
  try {
    return initializeAuth(app, {
      persistence: getReactNativePersistence(AsyncStorage)
    });
  } catch (error) {
    // Fast Refresh o una segunda evaluación pueden encontrar Auth ya creado.
    if ((error as { code?: string })?.code === "auth/already-initialized") {
      return getAuth(app);
    }
    throw error;
  }
}
