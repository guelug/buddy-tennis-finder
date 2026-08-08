import { Platform } from "react-native";
import mobileAds, {
  AdsConsent,
  AdsConsentStatus,
  MaxAdContentRating,
  TestIds
} from "react-native-google-mobile-ads";

/**
 * Publicidad nativa (AdMob).
 *
 * Solo se usa el formato *nativo*: el anuncio se pinta con los componentes de
 * la app para que no rompa el diseño. A cambio, la política de AdMob obliga a
 * etiquetarlo claramente como publicidad — de eso se encarga NativeAdCard.
 *
 * En desarrollo se usan SIEMPRE los identificadores de prueba de Google:
 * pedir anuncios reales desde un build de debug es motivo de suspensión de la
 * cuenta por tráfico inválido.
 */

const NATIVE_UNIT_IDS = {
  ios: "ca-app-pub-6613881091306161/6989997449",
  android: "ca-app-pub-6613881091306161/2330511792"
} as const;

/** Unidad de anuncio nativo de la plataforma, o la de pruebas en desarrollo. */
export function nativeAdUnitId(): string {
  if (__DEV__) return TestIds.NATIVE;
  if (Platform.OS === "ios") return NATIVE_UNIT_IDS.ios;
  if (Platform.OS === "android") return NATIVE_UNIT_IDS.android;
  return TestIds.NATIVE;
}

/** La publicidad solo existe en móvil; en web no se carga el SDK. */
export const ADS_SUPPORTED = Platform.OS === "ios" || Platform.OS === "android";

let started: Promise<boolean> | null = null;

/**
 * Arranca el SDK una sola vez, después de resolver el consentimiento.
 *
 * España está en el EEE, así que la normativa exige recoger consentimiento con
 * un CMP certificado antes de servir publicidad personalizada. Se usa el UMP de
 * Google: si el usuario no consiente, no se deja de mostrar publicidad, se
 * muestra NO personalizada, que es lo que permite la ley.
 *
 * Devuelve `false` si no se puede mostrar publicidad; nunca lanza, porque un
 * fallo de anuncios no debe impedir usar la app.
 */
export function startAds(): Promise<boolean> {
  if (!ADS_SUPPORTED) return Promise.resolve(false);
  if (started) return started;

  started = (async () => {
    try {
      const consent = await AdsConsent.gatherConsent();
      // `canRequestAds` es false mientras el formulario siga pendiente.
      if (!consent.canRequestAds) return false;

      await mobileAds().setRequestConfiguration({
        // La app admite adolescentes desde 13 años: hay que acotar el
        // contenido que puede servirse.
        maxAdContentRating: MaxAdContentRating.T,
        tagForUnderAgeOfConsent: consent.status === AdsConsentStatus.REQUIRED
      });
      await mobileAds().initialize();
      return true;
    } catch {
      // Sin red o con el CMP caído simplemente no hay anuncios.
      return false;
    }
  })();

  return started;
}
