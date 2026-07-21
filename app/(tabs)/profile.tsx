import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Alert, Text, View } from "react-native";
import { router } from "expo-router";
import Constants from "expo-constants";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { BallDrop } from "@/components/ball-bounce";
import { Chip } from "@/components/chip";
import { Icon, type IconName } from "@/components/icon";
import { BrandLockup } from "@/components/brand-lockup";
import { GroupedList, GroupedRow } from "@/components/grouped-list";
import { BroadcastHeader, GlassPanel, LiveBackground } from "@/components/live-visuals";
import { PlayerReviews } from "@/components/player-reviews";
import { PrimaryButton } from "@/components/primary-button";
import { Avatar } from "@/components/avatar";
import { ScreenShell } from "@/components/screen-shell";
import { averageReviewSkills, SkillRadar, skillsFromRating } from "@/components/skill-radar";
import { StarRating } from "@/components/star-rating";
import { CountUp } from "@/components/count-up";
import { WazeLogo } from "@/components/icons/waze-logo";
import { WebShell } from "@/components/web/web-shell";
import { levelLabel } from "@/lib/matching";
import { signOut, useAuth } from "@/lib/firebase-auth";
import { SUPPORTED_LANGUAGES, useI18n } from "@/lib/i18n";
import { PURCHASES_ENABLED } from "@/lib/features";
import { subscribeToPlayer, getClubs } from "@/lib/firestore";
import { averageStars, getMatchRooms, getReviewsForPlayer } from "@/lib/match-room";
import { getPlayerRanking } from "@/lib/competition";
import { openInWaze } from "@/lib/waze";
import { currentPlayer as seedPlayer, players as seedPlayers } from "@/data/seed";
import { broadcast, colors, radii, shadows, spacing, typography, usePlatformLayout, useThemeMode, type ThemePreference } from "@/theme";
import { Club, MatchReview, MatchRoom, Player, RankingEntry } from "@/types";

const APP_VERSION = Constants.expoConfig?.version ?? "1.0.0";

export default function ProfileScreen() {
  const { isWebDesktop } = usePlatformLayout();
  return isWebDesktop ? <ProfileWeb /> : <ProfileNative />;
}

function countryFlag(country: string) {
  switch (country) {
    case "Guatemala": return "🇬🇹";
    case "El Salvador": return "🇸🇻";
    case "España": return "🇪🇸";
    default: return "🌍";
  }
}

function formatLocation(player: Player) {
  return `${countryFlag(player.country)} ${player.city}, ${player.country}`;
}

/** Los días se guardan canónicamente en español — solo traducimos lo mostrado. */
const DAY_I18N_KEYS: Record<string, string> = {
  lunes: "days.lunes",
  martes: "days.martes",
  miercoles: "days.miercoles",
  jueves: "days.jueves",
  viernes: "days.viernes",
  sabado: "days.sabado",
  domingo: "days.domingo"
};

function displayDay(t: (key: string) => string, day: string) {
  const key = DAY_I18N_KEYS[day.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()];
  return key ? t(key) : day;
}

/** Los idiomas se guardan canónicamente en español — solo traducimos lo mostrado. */
const LANGUAGE_I18N_KEYS: Record<string, string> = {
  Español: "languages.spanish",
  Inglés: "languages.english",
  Francés: "languages.french",
  Alemán: "languages.german",
  Italiano: "languages.italian",
  Portugués: "languages.portuguese"
};

function displayLanguage(t: (key: string) => string, label: string) {
  const key = LANGUAGE_I18N_KEYS[label];
  return key ? t(key) : label;
}

// ---------------------------------------------------------------------------
// WEB — dashboard de jugador
// ---------------------------------------------------------------------------

function ProfileWeb() {
  const data = useProfileData();
  if (data.loading || !data.player) return <ProfileLoading />;

  const { player, clubs, ranking } = data;

  return (
    <LiveBackground overlay={0.5}>
      <WebShell width="wide">
        <BroadcastHeader
          kicker={data.t("profile.kicker")}
          title={player.name}
          subtitle={`${data.t("profile.yearsOld").replace("{age}", String(player.age))} · ${levelLabel(player.level)}${player.clubIds.length > 0 ? ` · ${player.clubIds.map((id) => clubs.find((c) => c.id === id)?.name ?? id).join(", ")}` : ""}`}
          trailing={
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
              <HeaderStat label={data.t("tabs.ranking")} value={ranking ? `#${ranking.rank}` : "—"} detail={ranking ? data.t("profile.stats.streakDetail").replace("{streak}", String(ranking.streak)) : ""} />
              <HeaderStat label={data.t("ranking.table.points")} value={ranking?.points ?? 0} detail={ranking ? data.t("ranking.metric.provisional") : data.t("profile.stats.noRanking")} countUp />
              <HeaderStat label={data.t("profile.stats.wins")} value={data.winRate !== null ? `${data.winRate}%` : "—"} detail={data.t("profile.stats.played").replace("{count}", String(data.playedCount))} />
            </View>
          }
        />

        <View style={{ alignItems: "stretch", flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
          {/* Identidad */}
          <GlassPanel style={{ flexBasis: 300, flexGrow: 1, minWidth: 280 }}>
            <View style={{ alignItems: "center", gap: spacing.sm }}>
              <NeonAvatar name={player.name} photoURL={player.photoURL} size={96} />
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 24 }}>{player.name}</Text>
                {player.verified ? <Icon name="check-badge" size={18} color={colors.hardCourt as string} /> : null}
              </View>
              <BadgeRow badges={data.badges} />
              {player.bio ? (
                <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, lineHeight: 20, textAlign: "center" }}>
                  {player.bio}
                </Text>
              ) : null}
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Icon name="map-pin" size={14} color={colors.neon as string} />
                <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "700" }}>{formatLocation(player)}</Text>
              </View>
            </View>
            <FormStreakStrip form={data.form} />
            <PrimaryButton
              label={data.t("profile.edit")}
              icon={<Icon name="pencil" size={16} color={colors.textOnBrand as string} />}
              onPress={() => router.push("/onboarding")}
            />
            <PrimaryButton
              label={data.t("profile.invite")}
              variant="outline"
              icon={<Icon name="send" size={16} color={colors.court as string} />}
              onPress={() => router.push("/invite" as never)}
            />
            {PURCHASES_ENABLED ? <PrimaryButton
              label={data.t("profile.privateLeagues")}
              variant="outline"
              icon={<Icon name="trophy" size={16} color={colors.court as string} />}
              onPress={() => router.push("/private-leagues" as never)}
            /> : null}
            {data.isConfigured ? (
              <PrimaryButton
                label={data.t("profile.signOut")}
                variant="outline"
                icon={<Icon name="sign-out" size={16} color={colors.court as string} />}
                onPress={data.handleSignOut}
              />
            ) : null}
          </GlassPanel>

          {/* Radar de habilidades */}
          <GlassPanel style={{ flexBasis: 320, flexGrow: 1, minWidth: 300 }}>
            <PanelTitle
              icon="zap"
              title={data.t("profile.skills.title")}
              hint={data.skillSummary.count > 0 ? data.t("profile.skills.hintReviews").replace("{count}", String(data.skillSummary.count)) : data.hasSelfSkills ? data.t("profile.skills.hintSelf") : data.t("profile.skills.hintRating")}
            />
            {data.skillSummary.count === 0 ? <RatingBasedSkillsNotice selfAssessed={data.hasSelfSkills} /> : null}
            <SkillRadar skills={data.skillSummary.skills} size={266} provisional={data.skillSummary.count === 0} />
          </GlassPanel>

          {/* Reputación */}
          <GlassPanel style={{ flexBasis: 300, flexGrow: 1, minWidth: 280 }}>
            <PanelTitle icon="star" title={data.t("profile.reputation.title")} hint={data.t("profile.reputation.hint")} />
            <ReputationSummary reviews={data.reviews} playedCount={data.playedCount} commentCount={data.commentCount} />
            <MatchStarsRow rivals={data.matchStars} />
          </GlassPanel>
        </View>

        <View style={{ alignItems: "flex-start", flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
          <GlassPanel style={{ flex: 1.3, minWidth: 340 }}>
            <PanelTitle icon="check-badge" title={data.t("profile.reviews.title")} hint={data.t("profile.reviews.hint")} />
            <PlayerReviews reviews={data.reviews} />
          </GlassPanel>

          <View style={{ flex: 1, gap: spacing.lg, minWidth: 300 }}>
            <GlassPanel>
              <PanelTitle icon="trophy" title={data.t("profile.achievements.title")} hint={data.t("profile.achievements.hint")} />
              <AchievementsRow playedCount={data.playedCount} streak={ranking?.streak ?? 0} reviews={data.reviews} />
            </GlassPanel>

            <GlassPanel>
              <PanelTitle icon="calendar" title={data.t("profile.availability.title")} hint={data.t("profile.availability.hint")} />
              {player.availability.map((slot) => (
                <View
                  key={slot.day}
                  style={{
                    alignItems: "center",
                    borderBottomColor: colors.border,
                    borderBottomWidth: 1,
                    flexDirection: "row",
                    justifyContent: "space-between",
                    paddingVertical: spacing.sm
                  }}
                >
                  <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary, fontSize: 15 }}>{displayDay(data.t, slot.day)}</Text>
                  <Text style={{ ...typography.caption, color: colors.neon }}>{slot.ranges.join(", ")}</Text>
                </View>
              ))}
              {player.clubIds.length > 0 ? (
                <View style={{ paddingTop: spacing.sm, gap: spacing.sm }}>
                  <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 15 }}>{data.t("profile.clubs.title")}</Text>
                  {player.clubIds.map((id) => {
                    const c = clubs.find((item) => item.id === id);
                    if (!c) return null;
                    return (
                      <View key={id} style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
                        <View style={{ flex: 1 }}>
                          <Text style={{ ...typography.body, color: colors.textPrimary }}>{c.name}</Text>
                          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
                            {c.city} · {data.t("profile.clubs.courts").replace("{count}", String(c.courts))}
                          </Text>
                        </View>
                        <PrimaryButton
                          label={data.t("common.directions")}
                          variant="outline"
                          icon={<WazeLogo size={19} color={colors.court} />}
                          fullWidth={false}
                          onPress={() => openInWaze(c.latitude, c.longitude, c.name)}
                          style={{ height: 38, paddingHorizontal: spacing.md }}
                        />
                      </View>
                    );
                  })}
                </View>
              ) : null}
            </GlassPanel>

            <SettingsPanel />
          </View>
        </View>

        <View style={{ alignItems: "center", gap: spacing.xs, paddingTop: spacing.md }}>
          <BrandLockup size="sm" />
          <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{`MatchPoint Tennis · v${APP_VERSION}`}</Text>
        </View>
      </WebShell>
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// NATIVO — tarjeta de jugador estilo concepto
// ---------------------------------------------------------------------------

function ProfileNative() {
  const data = useProfileData();
  if (data.loading || !data.player) return <ProfileLoading />;

  const { player, clubs, ranking } = data;

  return (
    <LiveBackground overlay={0.52}>
      <ScreenShell onRefresh={data.refresh}>
        {/* Identidad */}
        <Animated.View entering={FadeInUp.springify().damping(20)}>
          <GlassPanel>
            <View style={{ alignItems: "center", gap: spacing.sm }}>
              <NeonAvatar name={player.name} photoURL={player.photoURL} size={92} />
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 24 }}>{player.name}</Text>
                {player.verified ? <Icon name="check-badge" size={18} color={colors.hardCourt as string} /> : null}
              </View>
              {player.clubIds.length > 0 ? (
                <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                  <Icon name="building" size={12} color={colors.textSecondary as string} />
                  <Text style={{ ...typography.caption, color: colors.textSecondary }}>
                    {player.clubIds.map((id) => clubs.find((c) => c.id === id)?.name ?? id).join(", ")}
                  </Text>
                </View>
              ) : null}
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Icon name="map-pin" size={12} color={colors.neon as string} />
                <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "700" }}>{formatLocation(player)}</Text>
              </View>
              <BadgeRow badges={data.badges} />
            </View>

            <View style={{ flexDirection: "row", gap: spacing.sm, width: "100%" }}>
              <PrimaryButton
                label={data.t("profile.edit")}
                icon={<Icon name="pencil" size={16} color={colors.textOnBrand as string} />}
                onPress={() => router.push("/onboarding")}
                style={{ flex: 1 }}
              />
              <PrimaryButton
                label={data.t("profile.inviteShort")}
                variant="outline"
                icon={<Icon name="send" size={16} color={colors.court as string} />}
                onPress={() => router.push("/invite" as never)}
                style={{ flex: 1 }}
              />
            </View>

            {/* Stats broadcast */}
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              <StatCell label={data.t("tabs.ranking")} value={ranking ? `#${ranking.rank}` : "—"} />
              <StatCell label={data.t("ranking.table.points")} value={ranking?.points ?? 0} />
              <StatCell label={data.t("profile.stats.wins")} value={data.winRate !== null ? `${data.winRate}%` : "—"} />
              <StatCell label={data.t("ranking.table.streak")} value={`${ranking?.streak ?? 0} 🔥`} />
            </View>

            <FormStreakStrip form={data.form} />
          </GlassPanel>
        </Animated.View>

        {/* Radar */}
        <Animated.View entering={FadeIn.delay(90).springify()}>
          <GlassPanel>
            <PanelTitle
              icon="zap"
              title={data.t("profile.skills.title")}
              hint={data.skillSummary.count > 0 ? data.t("profile.skills.hintReviews").replace("{count}", String(data.skillSummary.count)) : data.hasSelfSkills ? data.t("profile.skills.hintSelf") : data.t("profile.skills.hintRating")}
            />
            {data.skillSummary.count === 0 ? <RatingBasedSkillsNotice selfAssessed={data.hasSelfSkills} /> : null}
            <SkillRadar skills={data.skillSummary.skills} size={252} provisional={data.skillSummary.count === 0} />
          </GlassPanel>
        </Animated.View>

        {/* Reputación */}
        <Animated.View entering={FadeIn.delay(140).springify()}>
          <GlassPanel>
            <PanelTitle icon="star" title={data.t("profile.reputation.title")} hint={data.t("profile.reputation.hint")} />
            <ReputationSummary reviews={data.reviews} playedCount={data.playedCount} commentCount={data.commentCount} />
            <MatchStarsRow rivals={data.matchStars} />
          </GlassPanel>
        </Animated.View>

        {/* Logros */}
        <Animated.View entering={FadeIn.delay(180).springify()}>
          <GlassPanel>
            <PanelTitle icon="trophy" title={data.t("profile.achievements.title")} hint={data.t("profile.achievements.hint")} />
            <AchievementsRow playedCount={data.playedCount} streak={ranking?.streak ?? 0} reviews={data.reviews} />
          </GlassPanel>
        </Animated.View>

        {/* Notas */}
        <Animated.View entering={FadeIn.delay(220).springify()}>
          <GlassPanel>
            <PlayerReviews reviews={data.reviews} />
          </GlassPanel>
        </Animated.View>

        <GroupedList title={data.t("profile.availability.title")}>
          {player.availability.length === 0 ? (
            <GroupedRow
              label={data.t("profile.availability.empty")}
              value={data.t("profile.availability.emptyHint")}
              icon="calendar"
              last
              onPress={() => router.push("/onboarding")}
            />
          ) : (
            player.availability.map((slot, index) => (
              <GroupedRow
                key={slot.day}
                label={displayDay(data.t, slot.day)}
                value={slot.ranges.join(", ")}
                icon="clock"
                last={index === player.availability.length - 1}
              />
            ))
          )}
        </GroupedList>

        {player.languages.length > 0 ? (
          <GroupedList title={data.t("profile.languages.title")}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, padding: spacing.base }}>
              {player.languages.map((lang) => (
                <Chip key={lang} label={displayLanguage(data.t, lang)} active />
              ))}
            </View>
          </GroupedList>
        ) : null}

        {player.clubIds.length > 0 ? (
          <GroupedList title={data.t("profile.clubs.title")}>
            {player.clubIds.map((id, index) => {
              const c = clubs.find((item) => item.id === id);
              if (!c) return null;
              return (
                <GroupedRow
                  key={id}
                  label={index === 0 ? `${c.name} ★` : c.name}
                  value={`${c.city} · ${data.t("profile.clubs.courts").replace("{count}", String(c.courts))}`}
                  icon="building"
                  onPress={() => router.push("/onboarding")}
                  last={index === player.clubIds.length - 1}
                  trailing={
                    <Icon name="chevron-right" size={16} color={colors.court as string} />
                  }
                />
              );
            })}
          </GroupedList>
        ) : null}

        <SettingsSection />

        <GroupedList title={data.t("profile.account")}>
          <GroupedRow label={data.t("profile.invite")} value={data.t("profile.inviteHint")} icon="send" onPress={() => router.push("/invite" as never)} />
          {PURCHASES_ENABLED ? <GroupedRow label={data.t("profile.privateLeagues")} icon="trophy" onPress={() => router.push("/private-leagues" as never)} /> : null}
          <GroupedRow label={data.t("profile.coachInterests")} value={data.t("profile.coachInterestsHint")} icon="users" onPress={() => router.push("/coach-interests" as never)} />
          <GroupedRow label={data.t("profile.edit")} icon="pencil" onPress={() => router.push("/onboarding")} />
          {data.isConfigured ? (
            <GroupedRow label={data.t("profile.signOut")} icon="sign-out" onPress={data.handleSignOut} />
          ) : null}
          <GroupedRow label={data.t("profile.privacy")} icon="globe" onPress={() => router.push("/privacy")} />
          <GroupedRow label={data.t("profile.terms")} icon="check-badge" onPress={() => router.push("/terms" as never)} />
          <GroupedRow label={data.t("profile.support")} icon="users" onPress={() => router.push("/support" as never)} />
          <GroupedRow label={data.t("profile.deleteAccount")} value={data.t("profile.deleteAccountHint")} icon="sign-out" iconColor={colors.danger as string} onPress={() => router.push("/delete-account" as never)} last />
        </GroupedList>

        <View style={{ alignItems: "center", gap: spacing.xs, paddingVertical: spacing.md }}>
          <BrandLockup size="sm" />
          <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{`MatchPoint Tennis · v${APP_VERSION}`}</Text>
        </View>
      </ScreenShell>
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// Sub-componentes del concepto
// ---------------------------------------------------------------------------

/** Ajustes de la app: apariencia (sistema/claro/oscuro) e idioma. */
function SettingsSection() {
  const { preference, setPreference } = useThemeMode();
  const { lang, setLang, t } = useI18n();
  const themeOptions: Array<{ value: ThemePreference; label: string }> = [
    { value: "system", label: t("settings.theme.system") },
    { value: "light", label: t("settings.theme.light") },
    { value: "dark", label: t("settings.theme.dark") }
  ];
  return (
    <GroupedList title={t("settings.title")}>
      <GroupedRow label={t("settings.appearance")} value={t("settings.appearanceHint")} icon="zap">
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, marginTop: spacing.xs }}>
          {themeOptions.map((option) => (
            <Chip
              key={option.value}
              active={preference === option.value}
              label={option.label}
              onPress={() => setPreference(option.value)}
            />
          ))}
        </View>
      </GroupedRow>
      <GroupedRow label={t("settings.language")} value={t("settings.languageHint")} icon="globe" last>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, marginTop: spacing.xs }}>
          {SUPPORTED_LANGUAGES.map((language) => (
            <Chip
              key={language.code}
              active={lang === language.code}
              label={language.label}
              onPress={() => setLang(language.code)}
            />
          ))}
        </View>
      </GroupedRow>
    </GroupedList>
  );
}

/** Ajustes para la versión web — mismo contenido en un panel glass. */
function SettingsPanel() {
  const { preference, setPreference } = useThemeMode();
  const { lang, setLang, t } = useI18n();
  const themeOptions: Array<{ value: ThemePreference; label: string }> = [
    { value: "system", label: t("settings.theme.system") },
    { value: "light", label: t("settings.theme.light") },
    { value: "dark", label: t("settings.theme.dark") }
  ];
  return (
    <GlassPanel>
      <PanelTitle icon="zap" title={t("settings.title")} hint={t("settings.appearanceHint")} />
      <View style={{ gap: spacing.xs }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 15 }}>{t("settings.appearance")}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {themeOptions.map((option) => (
            <Chip
              key={option.value}
              active={preference === option.value}
              label={option.label}
              onPress={() => setPreference(option.value)}
            />
          ))}
        </View>
      </View>
      <View style={{ gap: spacing.xs }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 15 }}>{t("settings.language")}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {SUPPORTED_LANGUAGES.map((language) => (
            <Chip
              key={language.code}
              active={lang === language.code}
              label={language.label}
              onPress={() => setLang(language.code)}
            />
          ))}
        </View>
      </View>
    </GlassPanel>
  );
}

function NeonAvatar({ name, photoURL, size }: { name: string; photoURL?: string | null; size: number }) {
  return (
    <View
      style={{
        borderColor: `${colors.neon}88`,
        borderRadius: 999,
        borderWidth: 2.5,
        boxShadow: shadows.courtGlow,
        padding: 3
      }}
    >
      <Avatar name={name} photoURL={photoURL} size={size} />
    </View>
  );
}

function RatingBasedSkillsNotice({ selfAssessed }: { selfAssessed: boolean }) {
  const { t } = useI18n();
  return (
    <View style={{ backgroundColor: colors.dangerBg, borderColor: `${colors.danger}66`, borderRadius: radii.md, borderWidth: 1, flexDirection: "row", gap: spacing.sm, padding: spacing.md }}>
      <Icon name="zap" size={18} color={colors.danger as string} />
      <View style={{ flex: 1, gap: 2 }}>
        <Text style={{ ...typography.caption, color: colors.danger, fontWeight: "900", letterSpacing: 0.7 }}>
          {selfAssessed ? t("profile.skills.noticeSelf.title") : t("profile.skills.noticeRating.title")}
        </Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
          {selfAssessed
            ? t("profile.skills.noticeSelf.body")
            : t("profile.skills.noticeRating.body")}
        </Text>
      </View>
    </View>
  );
}

type ProfileBadge = { icon: IconName; label: string };

function BadgeRow({ badges }: { badges: ProfileBadge[] }) {
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, justifyContent: "center" }}>
      {badges.map((badge, index) => (
        <Animated.View
          key={badge.label}
          entering={FadeIn.delay(150 + index * 70).springify()}
          style={{
            alignItems: "center",
            backgroundColor: index === 0 ? colors.courtLight : "rgba(234,243,228,0.06)",
            borderColor: index === 0 ? `${colors.neon}44` : colors.border,
            borderRadius: radii.pill,
            borderWidth: 1,
            flexDirection: "row",
            gap: 5,
            paddingHorizontal: spacing.md,
            paddingVertical: 5
          }}
        >
          <Icon name={badge.icon} size={12} color={(index === 0 ? colors.neon : colors.textSecondary) as string} />
          <Text
            style={{
              ...typography.footnote,
              color: index === 0 ? colors.neon : colors.textSecondary,
              fontWeight: "700"
            }}
          >
            {badge.label}
          </Text>
        </Animated.View>
      ))}
    </View>
  );
}

function StatCell({ label, value }: { label: string; value: string | number }) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.surfaceCourt,
        borderColor: colors.border,
        borderRadius: radii.md,
        borderWidth: 1,
        flex: 1,
        gap: 2,
        paddingVertical: spacing.sm
      }}
    >
      <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: 18 }}>{value}</Text>
      <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 10 }}>{label}</Text>
    </View>
  );
}

function HeaderStat({
  label,
  value,
  detail,
  countUp = false
}: {
  label: string;
  value: string | number;
  detail: string;
  countUp?: boolean;
}) {
  return (
    <View
      style={{
        backgroundColor: colors.surface,
        borderColor: `${colors.neon}22`,
        borderRadius: radii.lg,
        borderWidth: 1,
        flexGrow: 1,
        minWidth: 110,
        padding: spacing.md
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      {countUp && typeof value === "number" ? (
        <CountUp value={value} style={{ ...broadcast.rank, color: colors.textPrimary, fontSize: 34 }} />
      ) : (
        <Text style={{ ...broadcast.rank, color: colors.textPrimary, fontSize: 34 }}>{value}</Text>
      )}
      {detail ? <Text style={{ ...typography.footnote, color: colors.neon }}>{detail}</Text> : null}
    </View>
  );
}

/** Forma reciente: W/L con pop en cascada, estilo marcador del concepto. */
function FormStreakStrip({ form }: { form: Array<"W" | "L"> }) {
  const { t } = useI18n();
  return (
    <View style={{ gap: spacing.xs }}>
      <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 10, letterSpacing: 1.4 }}>
        {t("profile.form.title")}
      </Text>
      <View style={{ flexDirection: "row", gap: spacing.sm }}>
        {form.length === 0 ? (
          <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
            {t("profile.form.empty")}
          </Text>
        ) : (
          form.map((result, index) => (
            <BallDrop key={index} delay={200 + index * 80}>
              <View
                style={{
                  alignItems: "center",
                  backgroundColor: result === "W" ? colors.neon : "rgba(255,107,90,0.18)",
                  borderColor: result === "W" ? colors.neon : `${colors.danger}55`,
                  borderRadius: radii.sm,
                  borderWidth: 1,
                  boxShadow: result === "W" ? shadows.courtGlow : undefined,
                  height: 34,
                  justifyContent: "center",
                  width: 34
                }}
              >
                <Text
                  style={{
                    ...broadcast.stat,
                    color: result === "W" ? colors.textOnBall : colors.danger,
                    fontSize: 16
                  }}
                >
                  {result}
                </Text>
              </View>
            </BallDrop>
          ))
        )}
      </View>
    </View>
  );
}

function PanelTitle({ icon, title, hint }: { icon: IconName; title: string; hint: string }) {
  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.courtLight,
          borderRadius: radii.md,
          height: 34,
          justifyContent: "center",
          width: 34
        }}
      >
        <Icon name={icon} size={16} color={colors.neon as string} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{title}</Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{hint}</Text>
      </View>
    </View>
  );
}

function ReputationSummary({
  reviews,
  playedCount,
  commentCount
}: {
  reviews: MatchReview[];
  playedCount: number;
  commentCount: number;
}) {
  const avg = averageStars(reviews);
  const { t } = useI18n();
  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
      <View style={{ alignItems: "center", gap: 2 }}>
        <Text style={{ ...broadcast.scoreboard, color: colors.neon, fontSize: 40, lineHeight: 44 }}>
          {avg ? avg.toFixed(1) : "—"}
        </Text>
        <StarRating value={avg ?? 0} size={13} gap={2} />
      </View>
      <View style={{ flex: 1, gap: spacing.sm }}>
        <MiniCounter label={t("profile.reputation.played")} value={playedCount} />
        <MiniCounter label={t("profile.reputation.comments")} value={commentCount} />
      </View>
    </View>
  );
}

function MiniCounter({ label, value }: { label: string; value: number }) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.surfaceCourt,
        borderColor: colors.border,
        borderRadius: radii.sm,
        borderWidth: 1,
        flexDirection: "row",
        justifyContent: "space-between",
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.sm
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: 17 }}>{value}</Text>
    </View>
  );
}

/** Rivales mejor valorados con los que jugaste — "Estrellas del partido". */
function MatchStarsRow({ rivals }: { rivals: Array<{ player: Player; stars: number }> }) {
  const { t } = useI18n();
  if (rivals.length === 0) return null;
  return (
    <View style={{ gap: spacing.xs }}>
      <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 10, letterSpacing: 1.4 }}>
        {t("profile.matchStars.title")}
      </Text>
      <View style={{ flexDirection: "row", gap: spacing.lg }}>
        {rivals.map((rival, index) => (
          <BallDrop key={rival.player.id} delay={260 + index * 90}>
            <View style={{ alignItems: "center", gap: 4 }}>
              <View
                style={{
                  borderColor: `${colors.neon}66`,
                  borderRadius: 999,
                  borderWidth: 2,
                  padding: 2
                }}
              >
                <Avatar name={rival.player.name} size={48} />
              </View>
              <View style={{ alignItems: "center", flexDirection: "row", gap: 3 }}>
                <Icon name="star" size={10} color={colors.gold as string} />
                <Text style={{ ...typography.footnote, color: colors.textPrimary, fontWeight: "800" }}>
                  {rival.stars.toFixed(1)}
                </Text>
              </View>
            </View>
          </BallDrop>
        ))}
      </View>
    </View>
  );
}

/** Logros — se desbloquean con datos reales del jugador. */
function AchievementsRow({
  playedCount,
  streak,
  reviews
}: {
  playedCount: number;
  streak: number;
  reviews: MatchReview[];
}) {
  const avg = averageStars(reviews) ?? 0;
  const { t } = useI18n();
  const achievements: Array<{ icon: IconName; label: string; unlocked: boolean }> = [
    { icon: "check-badge", label: t("profile.achievements.first"), unlocked: playedCount >= 1 },
    { icon: "trophy", label: t("profile.achievements.five"), unlocked: playedCount >= 5 },
    { icon: "zap", label: t("profile.achievements.streak"), unlocked: streak >= 3 },
    { icon: "star", label: t("profile.achievements.reputation"), unlocked: avg >= 4.5 },
    { icon: "users", label: t("profile.achievements.captain"), unlocked: true }
  ];

  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
      {achievements.map((achievement, index) => (
        <BallDrop key={achievement.label} delay={220 + index * 70}>
          <View style={{ alignItems: "center", gap: 4, width: 74 }}>
            <View
              style={{
                alignItems: "center",
                backgroundColor: achievement.unlocked ? colors.courtLight : colors.surfaceCourt,
                borderColor: achievement.unlocked ? `${colors.neon}55` : colors.border,
                borderRadius: radii.pill,
                borderWidth: 1.5,
                boxShadow: achievement.unlocked ? shadows.courtGlow : undefined,
                height: 52,
                justifyContent: "center",
                width: 52
              }}
            >
              <Icon
                name={achievement.icon}
                size={22}
                color={(achievement.unlocked ? colors.neon : colors.textTertiary) as string}
              />
            </View>
            <Text
              style={{
                ...typography.footnote,
                color: achievement.unlocked ? colors.textSecondary : colors.textTertiary,
                fontSize: 10,
                textAlign: "center"
              }}
              numberOfLines={2}
            >
              {achievement.label}
            </Text>
          </View>
        </BallDrop>
      ))}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

function useProfileData() {
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const [player, setPlayer] = useState<Player | null>(null);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [reviews, setReviews] = useState<MatchReview[]>([]);
  const [rooms, setRooms] = useState<MatchRoom[]>([]);
  const [loading, setLoading] = useState(true);

  // El seed usa el id "me"; con Firebase el id es el uid.
  const playerId = isConfigured && user ? user.uid : "me";

  useEffect(() => {
    if (!isConfigured || !user) {
      setPlayer(seedPlayer);
      setLoading(false);
      getClubs().then(setClubs).catch(() => {});
      return;
    }
    const unsubscribe = subscribeToPlayer(user.uid, (next) => {
      setPlayer(next);
      setLoading(false);
    }, (error) => {
      console.warn("[matchpoint] profile subscription", error);
      setLoading(false);
    });
    getClubs().then(setClubs).catch(() => {});
    return unsubscribe;
  }, [user, isConfigured]);

  useEffect(() => {
    getReviewsForPlayer(playerId).then(setReviews).catch(() => {});
    getMatchRooms(playerId).then(setRooms).catch(() => {});
  }, [playerId]);

  /** Recarga para pull-to-refresh. El perfil en sí ya es una suscripción viva. */
  const refresh = async () => {
    await Promise.all([
      getReviewsForPlayer(playerId).then(setReviews),
      getMatchRooms(playerId).then(setRooms),
      getClubs().then(setClubs)
    ]).catch(() => {});
  };

  const handleSignOut = async () => {
    try {
      await signOut();
      router.replace("/login");
    } catch (error) {
      Alert.alert(t("profile.error.title"), describeError(error, t("onboarding.error.retryFallback")));
    }
  };

  const ranking: RankingEntry | undefined = useMemo(
    () => (player ? getPlayerRanking(playerId, player.level) : undefined),
    [player, playerId]
  );

  const validatedRooms = useMemo(
    () => rooms.filter((room) => room.status === "validated" && room.result),
    [rooms]
  );

  // Forma reciente: W/L de los últimos validados (izq = más antiguo).
  const form = useMemo<Array<"W" | "L">>(
    () =>
      validatedRooms
        .slice(0, 6)
        .map((room) => {
          const side = room.teamA.playerIds.includes(playerId) ? "A" : "B";
          return room.result!.winner === side ? ("W" as const) : ("L" as const);
        })
        .reverse(),
    [validatedRooms, playerId]
  );

  const winRate = useMemo(() => {
    if (form.length === 0) return null;
    return Math.round((form.filter((r) => r === "W").length / form.length) * 100);
  }, [form]);

  const playedCount = validatedRooms.length;
  const commentCount = useMemo(
    () => rooms.flatMap((room) => room.reviews).filter((review) => review.comment).length,
    [rooms]
  );

  const skillSummary = useMemo(
    () => averageReviewSkills(reviews.map((review) => review.skillRatings), player?.skills ?? skillsFromRating(player?.rating ?? 3)),
    [reviews, player]
  );

  const hasSelfSkills = Boolean(player?.skills);

  // Rivales mejor valorados con los que jugaste.
  const matchStars = useMemo(() => {
    const rivalIds = new Set<string>();
    for (const room of rooms) {
      const rivalTeam = room.teamA.playerIds.includes(playerId) ? room.teamB : room.teamA;
      for (const id of rivalTeam.playerIds) rivalIds.add(id);
    }
    return [...rivalIds]
      .map((id) => seedPlayers.find((p) => p.id === id))
      .filter((p): p is Player => !!p)
      .sort((a, b) => b.rating - a.rating)
      .slice(0, 3)
      .map((p) => ({ player: p, stars: p.rating }));
  }, [rooms, playerId]);

  const isCaptain = useMemo(
    () =>
      rooms.some((room) => {
        const myTeam = room.teamA.playerIds.includes(playerId) ? room.teamA : room.teamB;
        return myTeam.captainId === playerId;
      }),
    [rooms, playerId]
  );

  const badges = useMemo<ProfileBadge[]>(() => {
    const result: ProfileBadge[] = [];
    if (player?.verified) result.push({ icon: "check-badge", label: t("profile.badges.verified") });
    if (isCaptain) result.push({ icon: "users", label: t("profile.badges.captain") });
    if (ranking && ranking.rank <= 50) result.push({ icon: "trophy", label: "Top 50" });
    return result;
  }, [isCaptain, ranking, player?.verified, t]);

  return {
    player,
    clubs,
    reviews,
    rooms,
    ranking,
    form,
    winRate,
    playedCount,
    commentCount,
    matchStars,
    badges,
    skillSummary,
    hasSelfSkills,
    loading,
    isConfigured,
    refresh,
    handleSignOut,
    t
  };
}

function ProfileLoading() {
  return (
    <View style={{ alignItems: "center", backgroundColor: colors.background, flex: 1, justifyContent: "center" }}>
      <ActivityIndicator size="large" color={colors.neon} />
    </View>
  );
}

function describeError(error: unknown, fallback: string) {
  if (error instanceof Error) return error.message;
  return fallback;
}
