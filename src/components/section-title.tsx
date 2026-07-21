import * as React from "react";
import { Pressable, Text, View } from "react-native";
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming
} from "react-native-reanimated";
import { Icon } from "@/components/icon";
import { colors, spacing, typography } from "@/theme";

type SectionTitleProps = {
  title: string;
  actionLabel?: string;
  onAction?: () => void;
  live?: boolean;
};

export function SectionTitle({ title, actionLabel, onAction, live }: SectionTitleProps) {
  return (
    <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: spacing.sm }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        {live ? <PulseDot /> : null}
        <Text style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>{title}</Text>
      </View>
      {actionLabel && onAction ? (
        <Pressable onPress={onAction} style={({ pressed, hovered }) => ({
          alignItems: "center",
          flexDirection: "row",
          gap: 4,
          paddingHorizontal: 6,
          paddingVertical: 2,
          borderRadius: 8,
          backgroundColor: hovered ? "rgba(11,94,58,0.08)" : "transparent",
          transform: pressed ? [{ scale: 0.98 }] : undefined,
          transition: "background-color 0.15s ease"
        })}>
          <Text style={{ ...typography.caption, color: colors.court, fontWeight: "700" }}>{actionLabel}</Text>
          <Icon name="chevron-right" size={12} color={colors.court as string} />
        </Pressable>
      ) : null}
    </View>
  );
}

function PulseDot() {
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  React.useEffect(() => {
    scale.value = withRepeat(
      withTiming(2.2, { duration: 900, easing: Easing.out(Easing.quad) }),
      -1,
      false
    );
    opacity.value = withRepeat(
      withTiming(0, { duration: 900, easing: Easing.out(Easing.quad) }),
      -1,
      false
    );
  }, [scale, opacity]);

  const ringStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value
  }));

  return (
    <View style={{ height: 8, width: 8 }}>
      <Animated.View
        style={[
          {
            backgroundColor: colors.clay,
            borderRadius: 4,
            height: 8,
            position: "absolute",
            width: 8
          },
          ringStyle
        ]}
      />
      <View
        style={{
          backgroundColor: colors.clay,
          borderRadius: 4,
          height: 8,
          position: "absolute",
          width: 8
        }}
      />
    </View>
  );
}