import * as React from "react";
import { ImageBackground, Platform, Text, useWindowDimensions, View, type ViewStyle } from "react-native";
import { Card } from "@/components/card";
import { CourtRally } from "@/components/court-rally";
import { ProductFeatureIcon, type ProductFeatureIconName } from "@/components/icons/product-feature-icons";
import { broadcast, colors, radii, shadows, spacing, typography, useBreakpoint, useThemeMode } from "@/theme";

export const liveHeroDark = require("@/../assets/generated/tennis-live-hero.webp");
export const liveHeroLight = require("@/../assets/generated/tennis-live-hero-light.webp");
export const bgLoginLive = require("@/../assets/generated/bg-login-live.webp");
export const bgLoginLiveLight = require("@/../assets/generated/bg-login-live-light.jpg");
export const bgRankingLive = require("@/../assets/generated/bg-ranking-live.webp");
export const bgRankingLiveLight = require("@/../assets/generated/bg-ranking-live-light.jpg");
export const bgRivalRadar = require("@/../assets/generated/bg-rival-radar.webp");
export const bgRivalRadarLight = require("@/../assets/generated/bg-rival-radar-light.jpg");
export const bgMatchControl = require("@/../assets/generated/bg-match-control.webp");
export const bgMatchControlLight = require("@/../assets/generated/bg-match-control-light-clean.jpg");

type LiveBackgroundProps = React.PropsWithChildren<{
  light?: boolean;
  lightSource?: number;
  overlay?: number;
  lightOverlay?: number;
  source?: number;
  style?: ViewStyle;
}>;

export function LiveBackground({
  children,
  light,
  lightSource,
  lightOverlay,
  overlay,
  source,
  style
}: LiveBackgroundProps) {
  const { isLight } = useThemeMode();
  const { height: viewportHeight } = useWindowDimensions();
  const effectiveLight = light ?? isLight;
  const effectiveOverlay = effectiveLight
    ? lightOverlay ?? Math.max(overlay ?? 0.42, 0.55)
    : overlay ?? 0.58;
  const backgroundSource = effectiveLight ? (lightSource ?? liveHeroLight) : (source ?? liveHeroDark);

  const vignette = effectiveLight
    ? "radial-gradient(120% 90% at 50% 38%, rgba(255,255,255,0.28) 0%, rgba(255,255,255,0.08) 55%, rgba(255,255,255,0) 100%)"
    : "radial-gradient(125% 95% at 50% 40%, rgba(2,5,3,0.62) 0%, rgba(2,5,3,0.30) 50%, rgba(2,5,3,0) 100%)";

  return (
    <ImageBackground
      source={backgroundSource}
      resizeMode="cover"
      style={[
        {
          alignSelf: "stretch",
          flex: 1,
          minHeight: Platform.OS === "web" ? viewportHeight : "100%",
          minWidth: "100%",
          width: "100%"
        },
        style
      ]}
    >
      <View
        pointerEvents="none"
        style={{
          backgroundColor: effectiveLight
            ? `rgba(255,255,255,${effectiveOverlay})`
            : `rgba(4,7,5,${effectiveOverlay})`,
          bottom: 0,
          left: 0,
          position: "absolute",
          right: 0,
          top: 0
        }}
      />
      <View
        pointerEvents="none"
        style={{
          backgroundImage: vignette,
          bottom: 0,
          left: 0,
          position: "absolute",
          right: 0,
          top: 0
        }}
      />
      {children}
    </ImageBackground>
  );
}

export function BroadcastHeader({
  kicker,
  title,
  subtitle,
  trailing
}: {
  kicker: string;
  title: string;
  subtitle?: string;
  trailing?: React.ReactNode;
}) {
  const { isCompact } = useBreakpoint();

  return (
    <View
      style={{
        alignItems: isCompact ? "stretch" : "center",
        flexDirection: isCompact ? "column" : "row",
        gap: spacing.lg,
        justifyContent: "space-between"
      }}
    >
      <View style={{ flex: isCompact ? undefined : 1, minWidth: 0 }}>
        <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 12, letterSpacing: 2 }}>
          {kicker}
        </Text>
        <Text
          style={{
            ...broadcast.hero,
            color: colors.textPrimary,
            fontSize: isCompact ? 32 : 44,
            lineHeight: isCompact ? 34 : 46
          }}
        >
          {title}
        </Text>
        {subtitle ? (
          <Text style={{ ...typography.body, color: colors.textSecondary, marginTop: 4 }}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {trailing}
    </View>
  );
}

export function GlassPanel({
  children,
  style,
  pad = "lg"
}: React.PropsWithChildren<{ style?: ViewStyle | ViewStyle[]; pad?: keyof typeof spacing }>) {
  const { isLight } = useThemeMode();
  const extraStyle = Array.isArray(style) ? style : [style ?? {}];
  return (
    <Card
      variant="glass"
      pad={pad}
      style={[
        {
          backgroundColor: isLight ? "rgba(255,255,255,0.86)" : "rgba(14,20,15,0.58)",
          borderColor: isLight ? "rgba(27,55,36,0.14)" : "rgba(234,243,228,0.10)",
          boxShadow: isLight
            ? "0 16px 42px rgba(27,55,36,0.12), 0 2px 8px rgba(27,55,36,0.04)"
            : "0 22px 70px rgba(0,0,0,0.42), inset 0 1px 0 rgba(255,255,255,0.04)",
          backdropFilter: Platform.OS === "web" ? "blur(18px)" : undefined
        },
        ...extraStyle
      ]}
    >
      {children}
    </Card>
  );
}

export function LiveBallStage({
  label,
  size = 118,
  compact = false
}: {
  label?: string;
  size?: number;
  compact?: boolean;
}) {
  const court = size + (compact ? 26 : 46);
  return (
    <View style={{ alignItems: "center", justifyContent: "center", minHeight: court * 1.02, minWidth: court }}>
      <CourtRally size={court} label={label} />
    </View>
  );
}

const featureCards: Array<{
  icon: ProductFeatureIconName;
  title: string;
  body: string;
  stat: string;
}> = [
  { icon: "ranking-live", title: "Ranking beta", body: "Orden provisional de perfiles", stat: "Beta" },
  { icon: "rival-radar", title: "Rival Radar", body: "Encuentra rivales compatibles", stat: "86%" },
  { icon: "match-control", title: "Match Control", body: "Publica y gestiona reservas", stat: "En pista" },
  { icon: "rival-validation", title: "Validación rival", body: "Próxima fase del circuito", stat: "Próximamente" }
];

export function LandingFeatureCards({ light }: { light?: boolean }) {
  const { isCompact } = useBreakpoint();
  const { isLight } = useThemeMode();
  const effectiveLight = light ?? isLight;
  return (
    <View
      style={{
        flexDirection: "row",
        flexWrap: "wrap",
        gap: spacing.sm
      }}
    >
      {featureCards.map((item) => (
        <View
          key={item.title}
          style={{
            backgroundColor: effectiveLight ? "rgba(255,255,255,0.88)" : "rgba(14,20,15,0.55)",
            borderColor: effectiveLight ? "rgba(27,55,36,0.12)" : "rgba(234,243,228,0.10)",
            borderRadius: radii.lg,
            borderWidth: 1,
            boxShadow: effectiveLight ? "0 18px 48px rgba(27,55,36,0.10)" : shadows.card,
            flexBasis: isCompact ? "100%" : "46%",
            flexGrow: 1,
            minWidth: isCompact ? undefined : 210,
            padding: spacing.md
          }}
        >
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <ProductFeatureIcon name={item.icon} size={42} tone={effectiveLight ? "light" : "dark"} />
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={{ ...typography.subheadline, color: effectiveLight ? "#0E1B12" : colors.textPrimary }} numberOfLines={1}>
                {item.title}
              </Text>
              <Text style={{ ...typography.footnote, color: effectiveLight ? "#5E6D61" : colors.textSecondary }} numberOfLines={1}>
                {item.body}
              </Text>
            </View>
          </View>
          <View
            style={{
              backgroundColor: effectiveLight ? "rgba(82,122,0,0.14)" : colors.courtLight,
              borderRadius: radii.pill,
              marginTop: spacing.md,
              paddingHorizontal: spacing.sm,
              paddingVertical: 5,
              alignSelf: "flex-start"
            }}
          >
            <Text style={{ ...broadcast.jersey, color: effectiveLight ? "#527A00" : colors.neon, fontSize: 11 }}>
              {item.stat}
              </Text>
          </View>
        </View>
      ))}
    </View>
  );
}
