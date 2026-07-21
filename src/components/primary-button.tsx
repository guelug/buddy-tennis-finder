import * as React from "react";
import { Pressable, Text, View, type ViewStyle } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  interpolate
} from "react-native-reanimated";
import { colors, radii, spacing, typography, motion } from "@/theme";

type Variant = "solid" | "outline" | "ghost" | "glass" | "accent";
type Size = "md" | "lg";

type PrimaryButtonProps = {
  label: string;
  onPress: () => void;
  variant?: Variant;
  size?: Size;
  disabled?: boolean;
  /** Icono opcional a la izquierda del label. */
  icon?: React.ReactNode;
  style?: ViewStyle;
  textColor?: string;
  /** Expandir al ancho del contenedor. Default true. */
  fullWidth?: boolean;
};

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function PrimaryButton({
  label,
  onPress,
  variant = "solid",
  size = "md",
  disabled = false,
  icon,
  style,
  textColor: textColorOverride,
  fullWidth = true
}: PrimaryButtonProps) {
  const pressed = useSharedValue(0);
  const [hovered, setHovered] = React.useState(false);

  const animatedStyle = useAnimatedStyle(() => {
    const scale = interpolate(pressed.value, [0, 1], [1, 0.96]);
    const shadowOpacity = interpolate(pressed.value, [0, 1], [1, 0.55]);
    return {
      transform: [{ scale }],
      shadowOpacity: variant === "solid" || variant === "accent" ? shadowOpacity : undefined
    };
  }, []);

  const handlePressIn = () => {
    pressed.value = withSpring(1, motion.tap);
  };
  const handlePressOut = () => {
    pressed.value = withSpring(0, motion.tap);
  };

  const isSolid = variant === "solid";
  const isAccent = variant === "accent";
  const isGlass = variant === "glass";
  const isGhost = variant === "ghost";
  const isLarge = size === "lg";

  const height = isLarge ? 54 : 48;
  const padHorizontal = isLarge ? spacing.lg : spacing.base;

  const surface: ViewStyle = isSolid
    ? { backgroundColor: colors.court }
    : isAccent
      ? { backgroundColor: colors.gold }
      : isGlass
        ? { backgroundColor: colors.courtLight }
        : { backgroundColor: "transparent" };

  const borderColor =
    isGhost || isGlass
      ? "transparent"
      : isSolid || isAccent
        ? "transparent"
        : colors.borderStrong;

  const textColor =
    textColorOverride ??
    (isSolid
      ? colors.textOnBrand
      : isAccent
        ? colors.textOnBrand
        : isGlass
          ? colors.court
          : colors.court);

  const hoverStyle =
    !disabled && hovered
      ? {
          boxShadow:
            variant === "solid" || variant === "accent"
              ? "0 8px 28px -6px rgba(198,241,53,0.45)"
              : undefined,
          opacity: 0.92
        }
      : undefined;

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      disabled={disabled}
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      onHoverIn={() => setHovered(true)}
      onHoverOut={() => setHovered(false)}
      style={[
        animatedStyle,
        {
          alignItems: "center",
          flexDirection: "row",
          gap: spacing.sm,
          justifyContent: "center",
          height,
          paddingHorizontal: padHorizontal,
          borderRadius: radii.pill,
          borderWidth: isSolid || isAccent ? 0 : 1,
          borderCurve: "continuous",
          borderColor,
          opacity: disabled ? 0.45 : 1,
          width: fullWidth ? "100%" : undefined,
          ...surface,
          ...(isSolid || isAccent
            ? {
                boxShadow: isAccent
                  ? "0 6px 20px -4px rgba(245,197,66,0.5)"
                  : "0 6px 22px -4px rgba(198,241,53,0.55)"
              }
            : {})
        },
        hoverStyle,
        style
      ]}
    >
      {icon ? <View>{icon}</View> : null}
      {label ? (
        <Text
          style={{
            ...typography.bodyEmphasized,
            color: textColor,
            fontSize: isLarge ? 17 : 15,
            letterSpacing: -0.1
          }}
        >
          {label}
        </Text>
      ) : null}
    </AnimatedPressable>
  );
}
