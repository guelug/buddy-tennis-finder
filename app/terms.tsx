import { Text } from "react-native";
import { Card } from "@/components/card";
import { ScreenShell } from "@/components/screen-shell";
import { useI18n } from "@/lib/i18n";
import { colors, typography } from "@/theme";

const termKeys = ["platform", "results", "safety", "availability", "contact"] as const;

export default function TermsScreen() {
  const { t } = useI18n();
  return (
    <ScreenShell bottomInset={32}>
      <Card pad="lg">
        <Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>{t("terms.title")}</Text>
        <Text selectable style={{ ...typography.footnote, color: colors.textTertiary }}>{t("terms.updated")}</Text>
      </Card>
      {termKeys.map((section) => (
        <Card key={section}>
          <Text selectable style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>{t(`terms.${section}.title`)}</Text>
          <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t(`terms.${section}.body`)}</Text>
        </Card>
      ))}
    </ScreenShell>
  );
}
