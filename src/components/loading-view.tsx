import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { TennisBall } from "@/components/tennis-ball";
import { useI18n } from "@/lib/i18n";
import { colors, spacing, typography } from "@/theme";

/** Global loading screen with animated tennis ball. */
export function LoadingView() {
  const { t } = useI18n();
  return (
    <Animated.View
      entering={FadeIn.duration(300)}
      style={{
        alignItems: "center",
        backgroundColor: colors.background,
        flex: 1,
        justifyContent: "center",
        gap: spacing.md,
        padding: spacing.base
      }}
    >
      <TennisBall size={48} animated />
      <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("common.loading")}</Text>
    </Animated.View>
  );
}
