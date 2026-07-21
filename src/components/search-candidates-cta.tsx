import { useEffect } from "react";
import { View } from "react-native";
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
import { colors, spacing } from "@/theme";

type SearchCandidatesCtaProps = {
  loading?: boolean;
  count?: number;
  onPress: () => void;
};

/** CTA principal para buscar rivales — pulso dorado estilo Betguate. */
export function SearchCandidatesCta({ loading = false, count, onPress }: SearchCandidatesCtaProps) {
  const pulse = useSharedValue(1);

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

  const pulseStyle = useAnimatedStyle(() => ({
    transform: [{ scale: loading ? 1 : pulse.value }]
  }));

  const label = loading
    ? "Buscando rivales..."
    : count !== undefined && count > 0
      ? `Buscar candidatos · ${count} encontrados`
      : "Buscar candidatos";

  return (
    <Animated.View style={pulseStyle}>
      <PrimaryButton
        label={label}
        variant="solid"
        size="lg"
        disabled={loading}
        icon={<Icon name="search" size={18} color={colors.textOnBall as string} />}
        onPress={() => {
          if (process.env.EXPO_OS === "ios") Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
          onPress();
        }}
      />
      {!loading ? (
        <View
          style={{
            backgroundColor: `${colors.neon}55`,
            borderRadius: 999,
            bottom: -6,
            height: 12,
            left: spacing.xl,
            position: "absolute",
            right: spacing.xl,
            zIndex: -1
          }}
        />
      ) : null}
    </Animated.View>
  );
}
