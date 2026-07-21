import { View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming
} from "react-native-reanimated";
import { useEffect } from "react";
import { colors, radii } from "@/theme";

/**
 * Shimmer / skeleton placeholder estilo Betguate.
 * Usar en cards de carga para dar sensación de premium.
 */
export function Skeleton({
  width = "100%",
  height = 16,
  borderRadius = radii.md,
  style
}: {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: object;
}) {
  const translateX = useSharedValue(-200);

  useEffect(() => {
    translateX.value = withRepeat(
      withTiming(200, { duration: 1400 }),
      -1,
      false
    );
  }, [translateX]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }]
  }));

  return (
    <View
      style={[
        {
          width,
          height,
          borderRadius,
          backgroundColor: colors.border as string,
          overflow: "hidden"
        },
        style
      ]}
    >
      <Animated.View
        style={[
          animatedStyle,
          {
            width: "60%",
            height: "100%",
            backgroundColor: "rgba(255,255,255,0.55)"
          }
        ]}
      />
    </View>
  );
}

export function SkeletonCircle({ size = 48 }: { size?: number }) {
  return <Skeleton width={size} height={size} borderRadius={size / 2} />;
}
