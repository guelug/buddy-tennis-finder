import { Platform } from "react-native";

/**
 * Los pagos (anuncios de entrenador, ligas privadas) solo se muestran cuando
 * el backend de verificación de esa plataforma está operativo. Las banderas
 * se incrustan al compilar; por defecto (sin variables de entorno) ambas
 * quedan en `false`, así la app funciona sin necesitar Firebase Functions ni
 * el plan Blaze — el resto de la experiencia (rivales/partidos/ranking)
 * siempre está disponible.
 *
 * - Android: la verificación server-side (`functions/index.js`) llama a la
 *   API de Google Play y requiere Blaze. TODO: reactivar cuando se despliegue
 *   esa función (o se sustituya por Stripe u otra pasarela) y poner esta
 *   bandera a `true` en el entorno de build de Android.
 * - iOS: usa (o usará) la verificación oficial de Apple del recibo de
 *   StoreKit. TODO: `functions/index.js` hoy solo implementa verificación de
 *   Google Play — antes de activar esta bandera en iOS hay que añadir la
 *   verificación de recibos de Apple (App Store Server API o JWS de
 *   StoreKit 2) en el backend o en el cliente.
 */
const ANDROID_PURCHASES_ENABLED = process.env.EXPO_PUBLIC_ANDROID_PURCHASES_ENABLED === "true";
const IOS_PURCHASES_ENABLED = process.env.EXPO_PUBLIC_IOS_PURCHASES_ENABLED === "true";

export const PURCHASES_ENABLED = Platform.OS === "ios" ? IOS_PURCHASES_ENABLED : ANDROID_PURCHASES_ENABLED;
