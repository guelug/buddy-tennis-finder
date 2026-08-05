import { Switch, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { GroupedList, GroupedRow } from "@/components/grouped-list";
import { useNotificationPrefs } from "@/lib/notification-settings";
import { useI18n } from "@/lib/i18n";
import { colors, spacing, typography } from "@/theme";

/**
 * Ajustes generales + notificaciones.
 *
 *  - General: master de sonido de la app (bola, avisos, victoria).
 *  - Notificaciones: tres eventos de matchmaking (sin duplicar el sonido).
 * Ambos comparten `prefs.sound` de notification-settings.ts.
 */
export function GeneralSettings() {
  const { t } = useI18n();
  const { prefs, update } = useNotificationPrefs();

  return (
    <GroupedList title={t("settings.general.title")}>
      <GroupedRow
        icon="tennis"
        label={t("settings.general.sound")}
        value={t("settings.general.soundHint")}
        trailing={
          <Switch
            trackColor={{ false: colors.borderStrong as string, true: colors.neon as string }}
            thumbColor="#fff"
            value={prefs.sound}
            onValueChange={(value) => update({ sound: value })}
          />
        }
        last
      />
    </GroupedList>
  );
}

/**
 * Apartado de Notificaciones dentro de Ajustes. Tres interruptores de eventos
 * (todos ON por defecto). El sonido vive en GeneralSettings.
 */
export function NotificationSettings() {
  const { t } = useI18n();
  const { prefs, update } = useNotificationPrefs();

  const toggle = (key: "teamSeeking" | "matchInterest" | "autoMatch") => (
    <Switch
      trackColor={{ false: colors.borderStrong as string, true: colors.neon as string }}
      thumbColor="#fff"
      value={prefs[key]}
      onValueChange={(value) => update({ [key]: value })}
    />
  );

  return (
    <GroupedList title={t("settings.notifications.title")}>
      <GroupedRow
        icon="users"
        label={t("settings.notifications.teamSeeking")}
        value={t("settings.notifications.teamSeekingHint")}
        trailing={toggle("teamSeeking")}
      />
      <GroupedRow
        icon="calendar-plus"
        label={t("settings.notifications.matchInterest")}
        value={t("settings.notifications.matchInterestHint")}
        trailing={toggle("matchInterest")}
      />
      <GroupedRow
        icon="zap"
        label={t("settings.notifications.autoMatch")}
        value={t("settings.notifications.autoMatchHint")}
        trailing={toggle("autoMatch")}
        last
      />
      <View style={{ gap: 4, paddingHorizontal: spacing.base, paddingVertical: spacing.md }}>
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
          <Icon name="check-badge" size={13} color={colors.textTertiary as string} />
          <Text style={{ ...typography.caption, color: colors.textTertiary, fontWeight: "600" }}>
            {t("settings.notifications.onDeviceNote")}
          </Text>
        </View>
      </View>
    </GroupedList>
  );
}
