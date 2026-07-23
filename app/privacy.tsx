import { Text, View } from "react-native";
import { Card } from "@/components/card";
import { ScreenShell } from "@/components/screen-shell";
import { useI18n } from "@/lib/i18n";
import { colors, spacing, typography } from "@/theme";

const sectionKeys = ["data", "purpose", "location", "providers", "visibility", "retention", "contact"] as const;

export default function PrivacyScreen() {
  const { t } = useI18n();
  return (
    <ScreenShell bottomInset={32}>
      <Card pad="lg">
        <Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>{t("privacy.title")}</Text>
        <Text selectable style={{ ...typography.footnote, color: colors.textTertiary }}>{t("privacy.version")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("privacy.intro")}</Text>
      </Card>
      {sectionKeys.map((section) => (
        <Card key={section}>
          <Text selectable style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>{t(`privacy.${section}.title`)}</Text>
          <Text selectable style={{ ...typography.body, color: colors.textSecondary, fontSize: 15, lineHeight: 22 }}>{t(`privacy.${section}.body`)}</Text>
        </Card>
      ))}
      <View style={{ height: spacing.lg }} />
    </ScreenShell>
  );
}
