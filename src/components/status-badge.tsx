import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import { MatchStatus } from "@/types";

type StatusBadgeProps = {
  status: MatchStatus;
};

export function StatusBadge({ status }: StatusBadgeProps) {
  const { t } = useI18n();
  const config = {
    proposed: { label: t("status.proposed"), bg: colors.warningBg, fg: colors.warning },
    accepted: { label: t("status.accepted"), bg: colors.successBg, fg: colors.success },
    declined: { label: t("status.declined"), bg: colors.dangerBg, fg: colors.danger }
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
        <Text style={{ ...typography.caption, color: fg, fontWeight: "800", fontSize: 12, letterSpacing: 0.2 }}>
          {label}
        </Text>
      </View>
    </Animated.View>
  );
}
