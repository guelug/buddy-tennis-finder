import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeInUp, FadeIn } from "react-native-reanimated";
import { colors, spacing, typography, useBreakpoint } from "@/theme";

type WebPageHeaderProps = {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  /** Stats o acciones alineadas a la derecha en desktop. */
  trailing?: React.ReactNode;
};

/** Cabecera de página para web — título editorial + metadata, sin duplicar nav. */
export function WebPageHeader({ eyebrow, title, subtitle, trailing }: WebPageHeaderProps) {
  // En viewports angostos el trailing pasa debajo del título para no aplastarlo.
  const { isWide } = useBreakpoint();

  return (
    <Animated.View
      entering={FadeInUp.springify().damping(20)}
      style={{
        borderBottomColor: colors.border,
        borderBottomWidth: 1,
        flexDirection: isWide ? "row" : "column",
        gap: spacing.lg,
        justifyContent: "space-between",
        paddingBottom: spacing.lg
      }}
    >
      <View style={{ flex: isWide ? 1 : undefined, gap: spacing.xs, maxWidth: 640 }}>
        {eyebrow ? (
          <Animated.Text
            entering={FadeIn.delay(60)}
            style={{
              ...typography.caption,
              color: colors.court,
              fontSize: 12,
              letterSpacing: 1.4,
              textTransform: "uppercase"
            }}
          >
            {eyebrow}
          </Animated.Text>
        ) : null}
        <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: isWide ? 32 : 28, lineHeight: isWide ? 36 : 32 }}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 16, lineHeight: 24 }}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {trailing ? (
        <Animated.View
          entering={FadeIn.delay(120)}
          style={{ alignItems: isWide ? "flex-end" : "flex-start", gap: spacing.sm }}
        >
          {trailing}
        </Animated.View>
      ) : null}
    </Animated.View>
  );
}

type WebStatPillProps = {
  label: string;
  value: string | number;
};

export function WebStatPill({ label, value }: WebStatPillProps) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.surface,
        borderColor: colors.border,
        borderCurve: "continuous",
        borderRadius: 12,
        borderWidth: 1,
        minWidth: 100,
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.sm,
        boxShadow: "0 2px 8px -4px rgba(11,26,18,0.08)"
      }}
    >
      <Text style={{ ...typography.metric, color: colors.court, fontSize: 22, fontVariant: ["tabular-nums"] }}>
        {value}
      </Text>
      <Text style={{ ...typography.footnote, color: colors.textSecondary, fontWeight: "600" }}>{label}</Text>
    </View>
  );
}