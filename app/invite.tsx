import { Image, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { shareAppInvite, shareCommunityBanner } from "@/lib/share";
import { colors, radii, spacing, typography } from "@/theme";

const banner = require("@/../assets/share/matchpoint-share-banner.png");

export default function InviteScreen() {
  const { user } = useAuth();
  const { t } = useI18n();
  const name = user?.displayName?.split(" ")[0] || t("invite.fallbackName");
  return (
    <LiveBackground overlay={0.48}>
      <ScreenShell>
        <View style={{ gap: 4, paddingTop: spacing.lg }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900", letterSpacing: 1.4 }}>{t("invite.kicker")}</Text>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 32 }}>{t("invite.title")}</Text>
          <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("invite.body")}</Text>
        </View>
        <Image source={banner} resizeMode="cover" style={{ aspectRatio: 1080 / 1350, borderColor: `${colors.neon}44`, borderRadius: radii.xl, borderWidth: 1, width: "100%" }} />
        <View style={{ gap: spacing.sm }}>
          <PrimaryButton label={t("invite.message")} icon={<Icon name="send" size={18} color={colors.textOnBrand as string} />} onPress={() => void shareAppInvite(name)} />
          <PrimaryButton label={t("invite.banner")} variant="outline" icon={<Icon name="globe" size={18} color={colors.neon as string} />} onPress={() => void shareCommunityBanner(name)} />
        </View>
      </ScreenShell>
    </LiveBackground>
  );
}
