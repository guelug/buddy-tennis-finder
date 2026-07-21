import * as React from "react";
import { Pressable, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withSequence,
  withSpring,
  withTiming
} from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import Svg, { Polygon } from "react-native-svg";
import { colors } from "@/theme";

const STAR_POINTS =
  "12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2";

function StarGlyph({ size, filled, color }: { size: number; filled: boolean; color: string }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Polygon
        points={STAR_POINTS}
        fill={filled ? color : "none"}
        stroke={filled ? color : colors.borderStrong}
        strokeWidth={1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/**
 * Estrella individual con pop de selección: escala 1 → 1.45 → 1 con rotación
 * ligera, tipo Tinder/Duolingo. La cascada al elegir N estrellas se logra con
 * `popDelay` (las anteriores también celebran, en stagger).
 */
function PopStar({
  size,
  filled,
  color,
  popKey,
  popDelay
}: {
  size: number;
  filled: boolean;
  color: string;
  popKey: number;
  popDelay: number;
}) {
  const scale = useSharedValue(1);
  const rotate = useSharedValue(0);

  React.useEffect(() => {
    if (popKey === 0 || !filled) return;
    scale.value = withDelay(
      popDelay,
      withSequence(
        withTiming(1.45, { duration: 110 }),
        withSpring(1, { damping: 9, stiffness: 340 })
      )
    );
    rotate.value = withDelay(
      popDelay,
      withSequence(
        withTiming(-14, { duration: 80 }),
        withTiming(12, { duration: 90 }),
        withSpring(0, { damping: 10, stiffness: 300 })
      )
    );
  }, [popKey, filled, popDelay, scale, rotate]);

  const style = useAnimatedStyle(
    () => ({
      transform: [{ scale: scale.value }, { rotate: `${rotate.value}deg` }]
    }),
    []
  );

  return (
    <Animated.View style={style}>
      <StarGlyph size={size} filled={filled} color={color} />
    </Animated.View>
  );
}

type StarRatingProps = {
  value: number;
  /** Si se pasa, las estrellas son interactivas. */
  onChange?: (stars: number) => void;
  size?: number;
  gap?: number;
  color?: string;
};

/** Fila de 1-5 estrellas. Interactiva (con pop en cascada) o de solo lectura. */
export function StarRating({ value, onChange, size = 28, gap = 6, color }: StarRatingProps) {
  const starColor = color ?? (colors.gold as string);
  const [popKey, setPopKey] = React.useState(0);

  const select = (stars: number) => {
    if (!onChange) return;
    if (process.env.EXPO_OS === "ios") {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    onChange(stars);
    setPopKey((key) => key + 1);
  };

  return (
    <View style={{ flexDirection: "row", gap }}>
      {[1, 2, 3, 4, 5].map((star) => {
        const filled = star <= Math.round(value);
        const glyph = (
          <PopStar
            size={size}
            filled={filled}
            color={starColor}
            popKey={onChange ? popKey : 0}
            popDelay={star * 45}
          />
        );
        if (!onChange) {
          return <View key={star}>{glyph}</View>;
        }
        return (
          <Pressable
            key={star}
            onPress={() => select(star)}
            hitSlop={6}
            accessibilityRole="button"
            accessibilityLabel={`${star} estrellas`}
          >
            {glyph}
          </Pressable>
        );
      })}
    </View>
  );
}
