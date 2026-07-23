import { useState } from "react";
import { Alert, Linking, Text } from "react-native";
import { router } from "expo-router";
import { Card } from "@/components/card";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { useAuth } from "@/lib/firebase-auth";
import { deleteCurrentAccountAndData } from "@/lib/account-deletion";
import { useI18n } from "@/lib/i18n";
import { colors, typography } from "@/theme";

export default function DeleteAccountScreen() {
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);

  const confirmDelete = () => Alert.alert(
    t("delete.confirmTitle"),
    t("delete.confirmBody"),
    [
      { text: t("delete.keep"), style: "cancel" },
      { text: t("delete.continue"), style: "destructive", onPress: confirmDeleteFinal }
    ]
  );

  const confirmDeleteFinal = () => Alert.alert(
    t("delete.finalTitle"),
    t("delete.finalBody"),
    [
      { text: t("common.cancel"), style: "cancel" },
      { text: t("delete.finalAction"), style: "destructive", onPress: () => void performDelete() }
    ]
  );

  async function performDelete() {
    try {
      setBusy(true);
      await deleteCurrentAccountAndData();
      router.replace("/login");
    } catch (error) {
      Alert.alert(t("delete.failed"), error instanceof Error ? error.message : t("delete.contactSupport"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScreenShell bottomInset={32}>
      <Card pad="lg">
        <Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>{t("delete.title")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("delete.owner")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("delete.body")}</Text>
        {user && isConfigured ? (
          <PrimaryButton label={busy ? t("delete.deleting") : t("delete.button")} disabled={busy} variant="outline" onPress={confirmDelete} />
        ) : (
          <PrimaryButton label={t("delete.email")} onPress={() => Linking.openURL("mailto:support@puchica.uk?subject=Delete%20MatchPoint%20Tennis%20account")} />
        )}
      </Card>
      <Card>
        <Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>{t("delete.supportTitle")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{t("delete.supportBody")}</Text>
      </Card>
    </ScreenShell>
  );
}
