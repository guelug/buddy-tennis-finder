import * as React from "react";
import { Image, Text, View } from "react-native";
import {
  NativeAd,
  NativeAdView,
  NativeAsset,
  NativeAssetType,
  NativeMediaView
} from "react-native-google-mobile-ads";
import { Card } from "@/components/card";
import { ADS_SUPPORTED, nativeAdUnitId, startAds, subscribeAdsConsentChanges } from "@/lib/ads";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography, useThemeMode } from "@/theme";

/**
 * Anuncio nativo con el mismo aspecto que las tarjetas de novedades del inicio.
 *
 * Dos reglas que no son negociables y por eso van aquí y no en quien la usa:
 *
 * 1. La política de AdMob exige que el anuncio se distinga del contenido
 *    editorial. Aunque comparta estilo con las tarjetas vecinas, lleva
 *    siempre la etiqueta "Publicidad" en la misma posición donde las otras
 *    llevan su tema, para que nadie confunda un anuncio con una noticia.
 * 2. Si no hay anuncio no se pinta NADA: ni hueco, ni esqueleto, ni
 *    marcador. Un espacio vacío desmaquetaría la fila de tarjetas.
 */
export function NativeAdCard({ desktop, age }: { desktop: boolean; age?: number }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const [ad, setAd] = React.useState<NativeAd | null>(null);
  const [consentRevision, setConsentRevision] = React.useState(0);

  React.useEffect(() => subscribeAdsConsentChanges(() => setConsentRevision((value) => value + 1)), []);

  React.useEffect(() => {
    if (!ADS_SUPPORTED || typeof age !== "number") return;
    let active = true;
    let loaded: NativeAd | null = null;
    setAd(null);

    void (async () => {
      const ready = await startAds(age);
      if (!ready || !active) return;
      try {
        loaded = await NativeAd.createForAdRequest(nativeAdUnitId());
        if (!active) {
          // Llegó tarde: se libera o queda ocupando memoria nativa.
          loaded.destroy();
          return;
        }
        setAd(loaded);
      } catch {
        // Sin relleno publicitario disponible: la fila se queda como estaba.
      }
    })();

    return () => {
      active = false;
      setAd(null);
      loaded?.destroy();
    };
  }, [age, consentRevision]);

  if (!ad) return null;

  const scrim = isLight ? "rgba(3,8,5,.84)" : "rgba(3,8,5,.76)";

  return (
    <Card style={{ flexBasis: "46%", flexGrow: 1, minWidth: 150, overflow: "hidden", padding: 0 }}>
      <NativeAdView nativeAd={ad} style={{ flex: 1 }}>
        <View style={{ minHeight: desktop ? 300 : 220 }}>
          {ad.mediaContent ? (
            <NativeMediaView resizeMode="contain" style={{ backgroundColor: "#050906", height: desktop ? 170 : 105, width: "100%" }} />
          ) : <View style={{ backgroundColor: colors.courtLight, height: desktop ? 170 : 105 }} />}

          {/* AdMob requires attribution at the top of the native ad. Keep the
              top-right corner free for the SDK-managed AdChoices overlay. */}
          <View style={{ backgroundColor: colors.accentFill, borderRadius: radii.pill, elevation: 2, left: spacing.sm, minHeight: 18, paddingHorizontal: spacing.sm, paddingVertical: 3, position: "absolute", top: spacing.sm, zIndex: 2 }}>
            <Text style={{ ...typography.footnote, color: colors.onAccentFill, fontSize: 11, fontWeight: "900" }}>
              {t("ads.label")}
            </Text>
          </View>

          <View style={{ backgroundColor: scrim, flex: 1, gap: desktop ? spacing.sm : 4, padding: desktop ? spacing.xl : spacing.md }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              {ad.icon?.url ? (
                <NativeAsset assetType={NativeAssetType.ICON}>
                  <Image source={{ uri: ad.icon.url }} resizeMode="contain" style={{ borderRadius: 6, height: 28, width: 28 }} />
                </NativeAsset>
              ) : null}
              {ad.advertiser ? (
                <NativeAsset assetType={NativeAssetType.ADVERTISER}>
                  <Text numberOfLines={1} style={{ ...typography.footnote, color: "rgba(255,255,255,.72)", flex: 1, fontSize: 11 }}>
                    {ad.advertiser}
                  </Text>
                </NativeAsset>
              ) : null}
            </View>

            <NativeAsset assetType={NativeAssetType.HEADLINE}>
              <Text style={{ ...typography.subheadline, color: "#fff", fontSize: desktop ? 22 : 16 }}>
                {ad.headline}
              </Text>
            </NativeAsset>

            {desktop && ad.body ? (
              <NativeAsset assetType={NativeAssetType.BODY}>
                <Text numberOfLines={2} style={{ ...typography.footnote, color: "rgba(255,255,255,.78)", fontSize: desktop ? 14 : 12 }}>
                  {ad.body}
                </Text>
              </NativeAsset>
            ) : null}

            {ad.callToAction ? (
              <NativeAsset assetType={NativeAssetType.CALL_TO_ACTION}>
                <Text
                  style={{ ...typography.footnote, color: colors.accentFill, fontWeight: "900", marginTop: 2 }}
                >
                  {ad.callToAction}
                </Text>
              </NativeAsset>
            ) : null}
          </View>
        </View>
      </NativeAdView>
    </Card>
  );
}
