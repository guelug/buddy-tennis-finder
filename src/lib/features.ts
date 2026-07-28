import { Platform } from "react-native";

/**
 * Los pagos (anuncios de entrenador, ligas privadas) solo se muestran cuando
 * el backend de verificación de esa plataforma está operativo. Las banderas
 * se incrustan al compilar. En iOS quedan activadas por defecto porque la
 * verificación segura ya está desplegada; se pueden apagar de emergencia con
 * `EXPO_PUBLIC_IOS_PURCHASES_ENABLED=false` sin alterar Android.
 *
 * - Android: permanece desactivado hasta que la API de Google Play tenga el
 *   mismo flujo de verificación y entrega que iOS.
 * - iOS: cada transacción se verifica con App Store Server API en el backend
 *   protegido por Firebase Auth y App Check antes de finalizar StoreKit.
 */
const IOS_PURCHASES_ENABLED = process.env.EXPO_PUBLIC_IOS_PURCHASES_ENABLED !== "false";

export const PURCHASES_ENABLED = Platform.OS === "ios" && IOS_PURCHASES_ENABLED;
