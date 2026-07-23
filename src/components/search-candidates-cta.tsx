import { useEffect } from "react";
import { ActivityIndicator } from "react-native";
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming
} from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { useI18n } from "@/lib/i18n";
import { colors, spacing } from "@/theme";

type SearchCandidatesCtaProps = {
  loading?: boolean;
  count?: number;
  onPress: () => void;
};

/** CTA principal para buscar rivales — pulso dorado estilo Betguate. */
export function SearchCandidatesCta({ loading = false, count, onPress }: SearchCandidatesCtaProps) {
  const { t } = useI18n();
  const pulse = useSharedValue(1);
  const glow = useSharedValue(1);

  useEffect(() => {
    pulse.value = withRepeat(
      withSequence(
        withTiming(1.03, { duration: 900, easing: Easing.inOut(Easing.quad) }),
        withTiming(1, { duration: 900, easing: Easing.inOut(Easing.quad) })
      ),
      2,
      false
    );
  }, [pulse]);

  useEffect(() => {
    glow.value = withTiming(loading ? 0 : 1, { duration: 220 });
  }, [glow, loading]);

  const pulseStyle = useAnimatedStyle(() => ({
    transform: [{ scale: loading ? 1 : pulse.value }]
  }));

  // El glow baja/sube con fade para que el estado loading no dé un salto visual.
  const glowStyle = useAnimatedStyle(() => ({
    opacity: glow.value
  }));

  const label = loading
    ? t("rivals.cta.searching")
    : count !== undefined && count > 0
      ? t("rivals.cta.found").replace("{count}", String(count))
      : t("rivals.cta.default");

  return (
    <Animated.View style={pulseStyle}>
      <PrimaryButton
        label={label}
        variant="solid"
        size="lg"
        disabled={loading}
        icon={
          loading ? (
            <ActivityIndicator size="small" color={colors.textOnBall as string} />
          ) : (
            <Icon name="search" size={18} color={colors.textOnBall as string} />
          )
        }
        onPress={() => {
          if (process.env.EXPO_OS === "ios") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
          onPress();
        }}
      />
      <Animated.View
        pointerEvents="none"
        style={[
          glowStyle,
          {
            backgroundColor: `${colors.neon}55`,
            borderRadius: 999,
            bottom: -6,
            height: 12,
            left: spacing.xl,
            position: "absolute",
            right: spacing.xl,
            zIndex: -1
          }
        ]}
      />
    </Animated.View>
  );
}
