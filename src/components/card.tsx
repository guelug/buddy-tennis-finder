import { PropsWithChildren, useState } from "react";
import { Pressable, View, type ViewStyle, Platform } from "react-native";
import { BlurView } from "expo-blur";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
  interpolate
} from "react-native-reanimated";
import { colors, radii, shadows, spacing, motion, useThemeMode } from "@/theme";

type CardVariant = "elevated" | "plain" | "glass" | "premium" | "interactive";

type CardProps = PropsWithChildren<{
  variant?: CardVariant;
  style?: ViewStyle | ViewStyle[];
  /** Padding interno. Por defecto `base` (16). */
  pad?: keyof typeof spacing;
  /** Separación vertical entre hijos directos. Por defecto `md` (12). */
  gap?: keyof typeof spacing;
  /** Si la card responde al toque con escala. */
  onPress?: () => void;
}>;

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

/**
 * Superficie base de la app. Variantes:
 *  - `elevated` (default): fondo sólido, sombra suave, esquinas continuas.
 *  - `plain`: igual fondo, sin sombra (agrupaciones dentro de otra card).
 *  - `glass`: BlurView translúcido con fallback en web.
 *  - `premium`: fondo dorado suave, borde dorado, glow — para rankings y destacados.
 *  - `interactive`: reacciona al toque con escala y shadow.
 */
export function Card({ children, variant = "elevated", style, pad = "base", gap = "md", onPress }: CardProps) {
  const { isLight } = useThemeMode();
  const padding = spacing[pad];
  const rowGap = spacing[gap];

  const baseStyle: ViewStyle = {
    padding,
    gap: rowGap,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderCurve: "continuous",
    overflow: "hidden"
  };

  if (variant === "glass") {
    const glassStyle = {
      backgroundColor: isLight
        ? "rgba(255,255,255,0.82)"
        : "rgba(14,20,15,0.66)",
      borderColor: isLight
        ? "rgba(27,55,36,0.14)"
        : "rgba(234,243,228,0.10)",
      boxShadow: isLight
        ? "0 16px 44px rgba(27,55,36,0.10), 0 2px 8px rgba(27,55,36,0.04)"
        : "0 22px 70px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.04)"
    };
    if (Platform.OS === "web") {
      return (
        <View
          style={[
            baseStyle,
            glassStyle,
            { backdropFilter: "blur(18px)" } as ViewStyle & { backdropFilter: string },
            style
          ]}
        >
          {children}
        </View>
      );
    }
    return (
      <BlurView
        intensity={isLight ? 28 : 22}
        tint={isLight ? "systemChromeMaterialLight" : "systemChromeMaterialDark"}
        style={[
          baseStyle,
          {
            borderColor: glassStyle.borderColor,
            backgroundColor: isLight
              ? "rgba(255,255,255,0.62)"
              : "rgba(14,20,15,0.48)"
          },
          style
        ]}
      >
        {children}
      </BlurView>
    );
  }

  const variantStyle: ViewStyle =
    variant === "premium"
      ? {
          backgroundColor: isLight ? colors.goldSoft : colors.goldSoft,
          borderColor: isLight ? "rgba(155,106,0,0.22)" : `${colors.gold}55`,
          boxShadow: shadows.glowGold
        }
      : {
          backgroundColor: colors.surface,
          borderColor: colors.border,
          boxShadow:
            variant === "elevated" || variant === "interactive"
              ? (isLight ? "0 10px 28px rgba(27,55,36,0.08), 0 2px 8px rgba(27,55,36,0.04)" : shadows.card)
              : undefined
        };

  if (variant === "interactive" || onPress) {
    const extraStyle = Array.isArray(style) ? style : [style ?? {}];
    return (
      <InteractiveCard style={[baseStyle, variantStyle, ...extraStyle]} onPress={onPress}>
        {children}
      </InteractiveCard>
    );
  }

  return (
    <View style={[baseStyle, variantStyle, style]}>
      {children}
    </View>
  );
}

function InteractiveCard({
  children,
  style,
  onPress
}: {
  children: React.ReactNode;
  style: ViewStyle | ViewStyle[];
  onPress?: () => void;
}) {
  const pressed = useSharedValue(0);
  const hovered = useSharedValue(0);
  const [hoverRaised, setHoverRaised] = useState(false);

  const animatedStyle = useAnimatedStyle(() => {
    const scale = interpolate(pressed.value, [0, 1], [1, 0.98]);
    // En web el hover levanta la card un pelín (lift sutil tipo producto).
    const translateY = interpolate(hovered.value, [0, 1], [0, -2]);
    return { transform: [{ translateY }, { scale }] };
  }, []);

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={() => {
        pressed.value = withSpring(1, motion.tap);
      }}
      onPressOut={() => {
        pressed.value = withSpring(0, motion.tap);
      }}
      onHoverIn={Platform.OS === "web" ? () => {
        hovered.value = withTiming(1, { duration: 160 });
        setHoverRaised(true);
      } : undefined}
      onHoverOut={Platform.OS === "web" ? () => {
        hovered.value = withTiming(0, { duration: 200 });
        setHoverRaised(false);
      } : undefined}
      style={[
        animatedStyle,
        style,
        Platform.OS === "web"
          ? ({ cursor: onPress ? "pointer" : "default", transition: "box-shadow 0.2s ease, border-color 0.2s ease" } as object)
          : undefined,
        Platform.OS === "web" && hoverRaised
          ? {
              boxShadow: shadows.floating,
              borderColor: colors.borderStrong
            }
          : undefined
      ]}
    >
      {children}
    </AnimatedPressable>
  );
}
