import { Linking, Text } from "react-native";
import { Card } from "@/components/card";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { useI18n } from "@/lib/i18n";
import { colors, typography } from "@/theme";

export default function SupportScreen() {
  const { t } = useI18n();
  return (
    <ScreenShell bottomInset={32}>
      <Card pad="lg">
        <Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>{t("support.title")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("support.owner")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textPrimary }}>support@puchica.uk</Text>
        <PrimaryButton label={t("support.contact")} onPress={() => Linking.openURL("mailto:support@puchica.uk?subject=MatchPoint%20Tennis%20Support")} />
      </Card>
      <Card>
        <Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>{t("support.matches.title")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("support.matches.body")}</Text>
      </Card>
      <Card>
        <Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>{t("support.account.title")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("support.account.body")}</Text>
      </Card>
    </ScreenShell>
  );
}
