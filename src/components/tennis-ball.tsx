import { Image, Platform, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
  Easing
} from "react-native-reanimated";
import { useEffect } from "react";
import { colors } from "@/theme";

const realisticBall = require("@/../assets/generated/tennis-ball-realistic.webp");

/**
 * Pelota de tenis decorativa animada.
 * Usar como acento en heroes, empty states o loading.
 */
export function TennisBall({
  size = 24,
  animated = true,
  style
}: {
  size?: number;
  animated?: boolean;
  style?: object;
}) {
  const rotation = useSharedValue(0);
  const floatPhase = useSharedValue(0);

  useEffect(() => {
    if (!animated) return;
    rotation.value = withRepeat(
      withTiming(360, { duration: 5200, easing: Easing.linear }),
      -1,
      false
    );
    floatPhase.value = withRepeat(
      withTiming(1, { duration: 2600, easing: Easing.linear }),
      -1,
      false
    );
  }, [animated, rotation, floatPhase]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: animated ? Math.sin(floatPhase.value * Math.PI * 2) * size * 0.055 : 0 },
      { rotate: `${rotation.value}deg` }
    ]
  }));

  const outer = size + 8;

  return (
    <Animated.View
      style={[
        animatedStyle,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          overflow: "visible",
          boxShadow: Platform.OS === "web"
            ? `0 0 0 4px ${colors.courtLight}, 0 5px 14px rgba(0,0,0,0.18)`
            : "0 4px 10px rgba(0,0,0,0.25)"
        },
        style
      ]}
    >
      <View
        style={{
          width: outer,
          height: outer,
          borderRadius: outer / 2,
          backgroundColor: colors.courtLight,
          position: "absolute",
          left: -4,
          top: -4,
          alignItems: "center",
          justifyContent: "center"
        }}
      >
        <Image
          accessibilityIgnoresInvertColors
          source={realisticBall}
          resizeMode="contain"
          style={{
            height: size * 1.25,
            width: size * 1.25
          }}
        />
      </View>
    </Animated.View>
  );
}
