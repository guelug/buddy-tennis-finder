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
import { ADS_SUPPORTED, nativeAdUnitId, startAds } from "@/lib/ads";
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
export function NativeAdCard({ desktop }: { desktop: boolean }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const [ad, setAd] = React.useState<NativeAd | null>(null);

  React.useEffect(() => {
    if (!ADS_SUPPORTED) return;
    let active = true;
    let loaded: NativeAd | null = null;

    void (async () => {
      const ready = await startAds();
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
      loaded?.destroy();
    };
  }, []);

  if (!ad) return null;

  const scrim = isLight ? "rgba(3,8,5,.84)" : "rgba(3,8,5,.76)";

  return (
    <Card style={{ flexBasis: "46%", flexGrow: 1, minWidth: 150, overflow: "hidden", padding: 0 }}>
      <NativeAdView nativeAd={ad} style={{ flex: 1 }}>
        <View style={{ height: desktop ? 280 : 150, justifyContent: "flex-end" }}>
          {ad.mediaContent ? (
            <NativeMediaView resizeMode="cover" style={{ ...StyleSheetAbsoluteFill }} />
          ) : ad.icon?.url ? (
            <Image source={{ uri: ad.icon.url }} resizeMode="cover" style={{ ...StyleSheetAbsoluteFill }} />
          ) : null}

          <View style={{ backgroundColor: scrim, gap: desktop ? spacing.sm : 3, padding: desktop ? spacing.xl : spacing.md }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              {/* Misma píldora que el tema de una noticia, pero diciendo lo que es. */}
              <View style={{ backgroundColor: colors.accentFill, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 3 }}>
                <Text style={{ ...typography.footnote, color: colors.onAccentFill, fontWeight: "900" }}>
                  {t("ads.label")}
                </Text>
              </View>
              {ad.advertiser ? (
                <Text numberOfLines={1} style={{ ...typography.footnote, color: "rgba(255,255,255,.72)", flex: 1, fontSize: 11 }}>
                  {ad.advertiser}
                </Text>
              ) : null}
            </View>

            <NativeAsset assetType={NativeAssetType.HEADLINE}>
              <Text numberOfLines={2} style={{ ...typography.subheadline, color: "#fff", fontSize: desktop ? 22 : 17 }}>
                {ad.headline}
              </Text>
            </NativeAsset>

            <NativeAsset assetType={NativeAssetType.BODY}>
              <Text numberOfLines={2} style={{ ...typography.footnote, color: "rgba(255,255,255,.78)", fontSize: desktop ? 14 : 12 }}>
                {ad.body}
              </Text>
            </NativeAsset>

            {ad.callToAction ? (
              <NativeAsset assetType={NativeAssetType.CALL_TO_ACTION}>
                <Text
                  numberOfLines={1}
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

/** `StyleSheet.absoluteFillObject` sin importar StyleSheet solo para esto. */
const StyleSheetAbsoluteFill = { bottom: 0, left: 0, position: "absolute" as const, right: 0, top: 0 };
