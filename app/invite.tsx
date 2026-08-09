import { Image, Pressable, Text, useWindowDimensions, View } from "react-native";
import { useState } from "react";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { shareAppInvite, shareCommunityBanner, type CommunityShareFormat } from "@/lib/share";
import { colors, radii, spacing, typography } from "@/theme";

const FORMATS: Array<{ id: CommunityShareFormat; label: string; ratio: number; source: number }> = [
  { id: "story", label: "Story", ratio: 9 / 16, source: require("@/../assets/share/matchpoint-share-story-v2.png") },
  { id: "reel", label: "Reel", ratio: 9 / 16, source: require("@/../assets/share/matchpoint-share-reel.png") },
  { id: "post", label: "Post", ratio: 1, source: require("@/../assets/share/matchpoint-share-post.png") },
  { id: "message", label: "Message", ratio: 1, source: require("@/../assets/share/matchpoint-share-message.png") }
];

export default function InviteScreen() {
  const { user } = useAuth();
  const { t } = useI18n();
  const { width, height } = useWindowDimensions();
  const [format, setFormat] = useState<CommunityShareFormat>("story");
  const selected = FORMATS.find((item) => item.id === format) ?? FORMATS[0];
  const previewWidth = Math.min(width - spacing.base * 2, selected.ratio < 1 ? (height * 0.46) * selected.ratio : 440);
  const previewHeight = previewWidth / selected.ratio;
  const name = user?.displayName?.split(" ")[0] || t("invite.fallbackName");
  return (
    <LiveBackground overlay={0.48}>
      <ScreenShell>
        <View style={{ gap: 4, paddingTop: spacing.lg }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900", letterSpacing: 1.4 }}>{t("invite.kicker")}</Text>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 32 }}>{t("invite.title")}</Text>
          <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("invite.body")}</Text>
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
          {FORMATS.map((item) => (
            <Pressable
              key={item.id}
              accessibilityRole="button"
              accessibilityState={{ selected: format === item.id }}
              onPress={() => setFormat(item.id)}
              style={{ backgroundColor: format === item.id ? colors.accentFill : colors.surface, borderColor: format === item.id ? colors.accentFill : colors.border, borderRadius: radii.pill, borderWidth: 1, paddingHorizontal: spacing.md, paddingVertical: spacing.sm }}
            >
              <Text style={{ ...typography.caption, color: format === item.id ? colors.onAccentFill : colors.textPrimary, fontWeight: "800" }}>{item.label}</Text>
            </Pressable>
          ))}
        </View>
        <View style={{ alignItems: "center", width: "100%" }}>
          <Image source={selected.source} resizeMode="contain" style={{ borderColor: `${colors.neon}44`, borderRadius: radii.xl, borderWidth: 1, height: previewHeight, maxWidth: "100%", width: previewWidth }} />
        </View>
        <View style={{ gap: spacing.sm }}>
          <PrimaryButton label={t("invite.message")} icon={<Icon name="send" size={18} color={colors.textOnBrand as string} />} onPress={() => void shareAppInvite(name)} />
          <PrimaryButton label={`${t("invite.banner")} · ${selected.label}`} variant="outline" icon={<Icon name="globe" size={18} color={colors.neon as string} />} onPress={() => void shareCommunityBanner(name, format)} />
        </View>
      </ScreenShell>
    </LiveBackground>
  );
}
