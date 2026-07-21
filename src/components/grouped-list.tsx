import * as React from "react";
import { Pressable, Text, View } from "react-native";
import Animated, { FadeInUp, useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { Icon, type IconName } from "@/components/icon";
import { colors, radii, spacing, typography } from "@/theme";

type GroupedListProps = {
  title?: string;
  children: React.ReactNode;
};

/** Sección agrupada estilo iOS Settings — una sola superficie con filas internas. */
export function GroupedList({ title, children }: GroupedListProps) {
  return (
    <View style={{ gap: spacing.sm }}>
      {title ? (
        <Text
          style={{
            ...typography.caption,
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: "700",
            letterSpacing: 0.8,
            marginLeft: spacing.xs,
            textTransform: "uppercase"
          }}
        >
          {title}
        </Text>
      ) : null}
      <Animated.View
        entering={FadeInUp.delay(40).springify().damping(22)}
        style={{
          backgroundColor: colors.surface,
          borderColor: colors.border,
          borderCurve: "continuous",
          borderRadius: radii.lg,
          borderWidth: 1,
          overflow: "hidden"
        }}
      >
        {children}
      </Animated.View>
    </View>
  );
}

type GroupedRowProps = {
  label: string;
  value?: string;
  icon?: IconName;
  iconColor?: string;
  onPress?: () => void;
  trailing?: React.ReactNode;
  /** Última fila del grupo — sin separador inferior. */
  last?: boolean;
  children?: React.ReactNode;
};

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function GroupedRow({
  label,
  value,
  icon,
  iconColor,
  onPress,
  trailing,
  last = false,
  children
}: GroupedRowProps) {
  const pressed = useSharedValue(0);
  const animatedStyle = useAnimatedStyle(() => ({
    backgroundColor: pressed.value ? `${colors.borderStrong}` : "transparent",
    transform: [{ scale: 1 - pressed.value * 0.004 }]
  }));

  const content = (
    <View
      style={{
        alignItems: "center",
        flexDirection: "row",
        gap: spacing.md,
        minHeight: 50,
        paddingHorizontal: spacing.base,
        paddingVertical: spacing.md
      }}
    >
      {icon ? (
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.courtLight,
            borderRadius: radii.md,
            height: 34,
            justifyContent: "center",
            width: 34
          }}
        >
          <Icon name={icon} size={18} color={iconColor ?? (colors.court as string)} />
        </View>
      ) : null}
      <View style={{ flex: 1, gap: 3 }}>
        <Text style={{ ...typography.body, color: colors.textPrimary }}>{label}</Text>
        {value ? (
          <Text style={{ ...typography.caption, color: colors.textSecondary, fontWeight: "500" }}>
            {value}
          </Text>
        ) : null}
        {children}
      </View>
      {trailing ?? (onPress ? <Icon name="chevron-right" size={14} color={colors.textTertiary as string} /> : null)}
    </View>
  );

  const row = onPress ? (
    <AnimatedPressable
      onPress={onPress}
      accessibilityRole="button"
      onPressIn={() => { pressed.value = withSpring(1, { duration: 90 }); }}
      onPressOut={() => { pressed.value = withSpring(0, { duration: 130 }); }}
      style={[{ flex: 1 }, animatedStyle]}
    >
      {content}
    </AnimatedPressable>
  ) : (
    content
  );

  return (
    <View>
      {row}
      {!last ? (
        <View
          style={{
            backgroundColor: colors.border,
            height: 1,
            marginLeft: icon ? spacing.base + 34 + spacing.md : spacing.base
          }}
        />
      ) : null}
    </View>
  );
}
