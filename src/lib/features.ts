import { Platform } from "react-native";

/**
 * Los pagos (anuncios de entrenador, ligas privadas) solo se muestran cuando
 * el backend de verificación de esa plataforma está operativo. Las banderas
 * se incrustan al compilar y se pueden apagar de emergencia con variables de
 * entorno sin alterar la otra plataforma.
 *
 * - iOS: cada transacción se verifica con App Store Server API en el backend
 *   protegido por Firebase Auth y App Check antes de finalizar StoreKit.
 * - Android: cada compra se verifica con Google Play Developer API en el
 *   mismo backend antes de finalizar el acknowledge de billing.
 */
const IOS_PURCHASES_ENABLED = process.env.EXPO_PUBLIC_IOS_PURCHASES_ENABLED !== "false";
const ANDROID_PURCHASES_ENABLED = process.env.EXPO_PUBLIC_ANDROID_PURCHASES_ENABLED !== "false";

export const PURCHASES_ENABLED =
  (Platform.OS === "ios" && IOS_PURCHASES_ENABLED) ||
  (Platform.OS === "android" && ANDROID_PURCHASES_ENABLED);