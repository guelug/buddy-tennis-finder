import * as React from "react";
import { Text, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring
} from "react-native-reanimated";
import { colors, radii, spacing, typography } from "@/theme";

type RatingBarProps = {
  /** Valor de 0 a 5. */
  value: number;
  /** Mostrar el número al lado. Default true. */
  showValue?: boolean;
  /** Tamaño. Default md. */
  size?: "sm" | "md";
};

/**
 * Barra de rating visual estilo "pelota de tenis" rellena.
 * Reemplaza el número seco 4.7 por algo más visual y moderno.
 */
export function RatingBar({ value, showValue = true, size = "md" }: RatingBarProps) {
  const clamped = Math.max(0, Math.min(5, value));
  const percent = (clamped / 5) * 100;
  const trackHeight = size === "sm" ? 6 : 9;
  const progress = useSharedValue(0);

  React.useEffect(() => {
    progress.value = withSpring(percent / 100, { damping: 14, stiffness: 180 });
  }, [percent, progress]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${progress.value * 100}%`
  }));

  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: spacing.sm }}>
      <View
        style={{
          backgroundColor: colors.border,
          borderRadius: radii.pill,
          flex: 1,
          height: trackHeight,
          overflow: "hidden"
        }}
      >
        <Animated.View
          style={[
            {
              backgroundColor: colors.court,
              borderRadius: radii.pill,
              height: "100%"
            },
            animatedStyle
          ]}
        />
      </View>
      {showValue ? (
        <Text
          style={{
            ...typography.bodyEmphasized,
            color: colors.textPrimary,
            fontVariant: ["tabular-nums"],
            fontSize: size === "sm" ? 13 : 15
          }}
        >
          {clamped.toFixed(1)}
        </Text>
      ) : null}
    </View>
  );
}
