import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { colors, radii, spacing, typography } from "@/theme";
import { MatchStatus } from "@/types";

type StatusBadgeProps = {
  status: MatchStatus;
};

/** Badge de estado de un partido (proposed/accepted/declined). */
export function StatusBadge({ status }: StatusBadgeProps) {
  const config = {
    proposed: { label: "Pendiente", bg: colors.warningBg, fg: colors.warning },
    accepted: { label: "Aceptado", bg: colors.successBg, fg: colors.success },
    declined: { label: "Cancelado", bg: colors.dangerBg, fg: colors.danger }
  } as const;

  const { label, bg, fg } = config[status];

  return (
    <Animated.View entering={FadeIn.springify()}>
      <View
        style={{
          backgroundColor: bg,
          borderRadius: radii.pill,
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.xs,
          borderWidth: 1,
          borderColor: `${fg}33`
        }}
      >
        <Text
          style={{
            ...typography.caption,
            color: fg,
            fontWeight: "800",
            fontSize: 12,
            letterSpacing: 0.2
          }}
        >
          {label}
        </Text>
      </View>
    </Animated.View>
  );
}
