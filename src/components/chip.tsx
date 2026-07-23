import * as React from "react";
import { Platform, Pressable, Text, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  interpolate
} from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { colors, radii, spacing, typography, motion } from "@/theme";

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const releaseSpring = { damping: 18, stiffness: 320, mass: 0.8 };

type ChipProps = {
  label: string;
  active?: boolean;
  onPress?: () => void;
  /** Mantener pulsado (p. ej. marcar club principal). */
  onLongPress?: () => void;
  /** Estilo de selección. Por defecto `solid` (relleno al activarse). */
  icon?: React.ReactNode;
  disabled?: boolean;
};

/**
 * Pill seleccionable/unificado. Reemplaza los componentes `Chip` que estaban
 * duplicados en onboarding.tsx e index.tsx.
 *
 * Animación de escala con spring al presionar para sensación nativa.
 */
export function Chip({
  label,
  active = false,
  onPress,
  onLongPress,
  icon,
  disabled = false
}: ChipProps) {
  const pressed = useSharedValue(0);
  const [hovered, setHovered] = React.useState(false);

  const animatedStyle = useAnimatedStyle(() => {
    const scale = interpolate(pressed.value, [0, 1], [1, 0.92]);
    return { transform: [{ scale }] };
  }, []);

  return (
    <AnimatedPressable
      onPress={onPress}
      onLongPress={
        onLongPress
          ? () => {
              // Feedback táctil para distinguir "mantener pulsado" de un tap.
              if (Platform.OS !== "web") void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
              onLongPress();
            }
          : undefined
      }
      // 280ms convertía taps normales (sobre todo en Android/Huawei) en
      // long-press: al tocar un club seleccionado lo marcaba principal en vez
      // de deseleccionarlo. 500ms es el umbral estándar de "mantener pulsado".
      delayLongPress={500}
      onPressIn={() => {
        pressed.value = withSpring(1, motion.spring);
      }}
      onPressOut={() => {
        pressed.value = withSpring(0, releaseSpring);
      }}
      onHoverIn={Platform.OS === "web" ? () => setHovered(true) : undefined}
      onHoverOut={Platform.OS === "web" ? () => setHovered(false) : undefined}
      disabled={disabled || (!onPress && !onLongPress)}
      accessibilityRole="button"
      accessibilityState={{ selected: active, disabled }}
      style={[
        animatedStyle,
        {
          alignItems: "center",
          flexDirection: "row",
          gap: spacing.xs,
          backgroundColor: active ? colors.court : colors.surface,
          borderColor: active ? colors.court : hovered && !disabled ? colors.neon : colors.borderStrong,
          borderRadius: radii.pill,
          borderWidth: 1,
          borderCurve: "continuous",
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.sm,
          opacity: disabled ? 0.45 : 1,
          boxShadow: active
            ? "0 4px 12px -4px rgba(11,94,58,0.30), 0 1px 3px -1px rgba(11,26,18,0.06)"
            : "0 1px 2px rgba(11,26,18,0.04)"
        },
        Platform.OS === "web"
          ? ({ cursor: disabled ? "default" : "pointer", transition: "border-color 0.18s ease, box-shadow 0.18s ease" } as object)
          : undefined
      ]}
    >
      {icon ? <View>{icon}</View> : null}
      <Text
        style={{
          ...typography.caption,
          color: active ? colors.textOnBrand : colors.textPrimary,
          letterSpacing: 0.1,
          fontWeight: active ? "700" : "500"
        }}
      >
        {label}
      </Text>
    </AnimatedPressable>
  );
}
