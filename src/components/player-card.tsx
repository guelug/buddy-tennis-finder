import * as React from "react";
import { Platform, Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import Animated, { FadeIn } from "react-native-reanimated";
import { Card } from "@/components/card";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { Avatar } from "@/components/avatar";
import { WazeLogo } from "@/components/icons/waze-logo";
import { compatibilityPct, levelLabel } from "@/lib/matching";
import { openInWaze } from "@/lib/waze";
import { broadcast, colors, radii, shadows, spacing, typography, useThemeMode } from "@/theme";
import { Club, MatchCandidate } from "@/types";

type PlayerCardProps = {
  candidate: MatchCandidate;
  clubs: Club[];
  index?: number;
  /** `web` = tarjeta rica para grillas; `native` = fila compacta para móvil. */
  variant?: "native" | "web";
};

export function PlayerCard({ candidate, clubs, index = 0, variant = "native" }: PlayerCardProps) {
  if (variant === "web") {
    return <PlayerCardWeb candidate={candidate} clubs={clubs} index={index} />;
  }
  return <PlayerCardNative candidate={candidate} clubs={clubs} index={index} />;
}

function useCandidateClubs(candidate: MatchCandidate, clubs: Club[]) {
  const ownClubs = clubs.filter((club) => candidate.player.clubIds.includes(club.id));
  return { ownClubs, firstClub: ownClubs[0] };
}

function PlayerCardNative({ candidate, clubs, index = 0 }: Omit<PlayerCardProps, "variant">) {
  const { isLight } = useThemeMode();
  const { ownClubs, firstClub } = useCandidateClubs(candidate, clubs);
  const highlightBg = isLight ? "rgba(82,122,0,0.07)" : "rgba(22,33,26,0.94)";
  const topReason = candidate.reasons[0];
  const nextSlot = candidate.sharedSlots[0] ?? "Horario flexible";
  const isDemo = candidate.player.isDemo === true;
  const openProfile = () => {
    if (!isDemo) router.push(`/player/${candidate.player.id}` as never);
  };

  const handleWaze = () => {
    if (firstClub) openInWaze(firstClub.latitude, firstClub.longitude, firstClub.name);
  };

  return (
    <Animated.View entering={FadeIn.delay(index * 60).springify().damping(18)}>
      <Card
        variant="interactive"
        style={{
          backgroundColor: index === 0 ? highlightBg : colors.surface,
          borderColor: index === 0 ? `${colors.neon}44` : colors.border,
          boxShadow: index === 0 ? shadows.courtGlow : shadows.card
        }}
      >
        <View
          style={{
            height: 4,
            left: 0,
            position: "absolute",
            right: 0,
            top: 0,
            backgroundColor: colors.neon,
            opacity: index === 0 ? 1 : 0.24
          }}
        />
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
          <Pressable accessibilityLabel={isDemo ? `${candidate.player.name}, perfil de muestra` : `Ver perfil de ${candidate.player.name}`} disabled={isDemo} onPress={openProfile}>
            <Avatar name={candidate.player.name} photoURL={candidate.player.photoURL} size={56} />
            <View
              style={{
                alignItems: "center",
                backgroundColor: colors.surfaceCourt,
                borderColor: colors.borderStrong,
                borderRadius: radii.pill,
                borderWidth: 1,
                bottom: -4,
                height: 22,
                justifyContent: "center",
                position: "absolute",
                right: -4,
                width: 22
              }}
            >
              <Icon name="zap" size={11} color={colors.neon as string} />
            </View>
          </Pressable>
          <View style={{ flex: 1, gap: 3 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text
                style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1 }}
                numberOfLines={1}
              >
                {candidate.player.name}
              </Text>
              {isDemo ? <DemoBadge /> : null}
              <MatchScoreBadge score={candidate.score} compact />
            </View>
            <Text style={{ ...typography.caption, color: colors.textSecondary, fontWeight: "500" }}>
              {candidate.player.age} años · {levelLabel(candidate.player.level)} · ★{" "}
              {candidate.player.rating.toFixed(1)}
            </Text>
            {firstClub ? (
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Icon name="map-pin" size={12} color={colors.textTertiary as string} />
                <Text style={{ ...typography.footnote, color: colors.textTertiary, flex: 1 }} numberOfLines={1}>
                  {ownClubs.map((club) => club.name).join(" · ")}
                </Text>
              </View>
            ) : null}
          </View>
        </View>

        <View style={{ flexDirection: "row", gap: spacing.sm }}>
          <MiniSignal label="Slot" value={nextSlot.replace("-", "–")} />
          <MiniSignal label="Afinidad" value={`${compatibilityPct(candidate.score)}%`} accent />
        </View>

        {topReason ? <ReasonPill reason={topReason} extra={candidate.reasons.length - 1} /> : null}

        {isDemo ? <DemoNotice /> : (
          <CardActionBar
            onProfile={openProfile}
            onWaze={firstClub ? handleWaze : undefined}
            photoURL={candidate.player.photoURL ?? undefined}
            name={candidate.player.name}
          />
        )}
      </Card>
    </Animated.View>
  );
}

function PlayerCardWeb({ candidate, clubs, index = 0 }: Omit<PlayerCardProps, "variant">) {
  const { isLight } = useThemeMode();
  const highlightBgWeb = isLight ? "rgba(82,122,0,0.07)" : "rgba(22,33,26,0.96)";
  const { ownClubs, firstClub } = useCandidateClubs(candidate, clubs);
  const nextSlot = candidate.sharedSlots[0] ?? "Horario flexible";
  const isDemo = candidate.player.isDemo === true;
  const openProfile = () => {
    if (!isDemo) router.push(`/player/${candidate.player.id}` as never);
  };

  const handleWaze = () => {
    if (firstClub) openInWaze(firstClub.latitude, firstClub.longitude, firstClub.name);
  };

  return (
    <Animated.View entering={FadeIn.delay(index * 50).springify().damping(18)} style={{ height: "100%" }}>
      <Card
        pad="lg"
        gap="md"
        style={{
          backgroundColor: index === 0 ? highlightBgWeb : colors.surface,
          borderColor: index === 0 ? `${colors.neon}40` : colors.border,
          height: "100%",
          minHeight: 282,
          ...(Platform.OS === "web"
            ? ({ cursor: "default", transition: "box-shadow 0.2s ease" } as object)
            : {})
        }}
      >
        <View
          style={{
            backgroundColor: index === 0 ? colors.neon : colors.courtLight,
            borderRadius: radii.pill,
            height: 5,
            left: spacing.lg,
            position: "absolute",
            right: spacing.lg,
            top: 0
          }}
        />
        <View style={{ alignItems: "flex-start", flexDirection: "row", gap: spacing.md }}>
          <Pressable accessibilityLabel={isDemo ? `${candidate.player.name}, perfil de muestra` : `Ver perfil de ${candidate.player.name}`} disabled={isDemo} onPress={openProfile}>
            <Avatar name={candidate.player.name} photoURL={candidate.player.photoURL} size={66} />
            <View
              style={{
                alignItems: "center",
                backgroundColor: colors.courtDeep,
                borderColor: "rgba(198,241,53,0.33)",
                borderRadius: radii.pill,
                borderWidth: 1,
                bottom: -5,
                flexDirection: "row",
                gap: 3,
                paddingHorizontal: 6,
                paddingVertical: 2,
                position: "absolute",
                right: -8
              }}
            >
              <Icon name="star" size={9} color="#C6F135" />
              <Text style={{ ...typography.footnote, color: "#C6F135", fontSize: 10, fontWeight: "800" }}>
                {candidate.player.rating.toFixed(1)}
              </Text>
            </View>
          </Pressable>
          <View style={{ flex: 1, gap: 4 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1, fontSize: 18 }}>
                {candidate.player.name}
              </Text>
              {isDemo ? <DemoBadge /> : null}
              <MatchScoreBadge score={candidate.score} />
            </View>
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14 }}>
              {candidate.player.age} años · {levelLabel(candidate.player.level)}
            </Text>
            {firstClub ? (
              <Text style={{ ...typography.caption, color: colors.textTertiary }} numberOfLines={1}>
                {ownClubs.map((club) => club.name).join(" · ")}
              </Text>
            ) : null}
          </View>
        </View>

        {candidate.player.bio ? (
          <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, lineHeight: 20 }} numberOfLines={2}>
            {candidate.player.bio}
          </Text>
        ) : null}

        <View style={{ flexDirection: "row", gap: spacing.sm }}>
          <MiniSignal label="Próximo slot" value={nextSlot.replace("-", "–")} />
          <MiniSignal label="Respuesta" value={`${candidate.player.responseRate}%`} />
        </View>

        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {candidate.reasons.map((reason) => (
            <ReasonPill key={reason} reason={reason} />
          ))}
        </View>

        <View
          style={{
            height: 1,
            backgroundColor: colors.border,
            marginVertical: spacing.xs
          }}
        />

        {isDemo ? <DemoNotice /> : (
          <CardActionBar
            onProfile={openProfile}
            onWaze={firstClub ? handleWaze : undefined}
            photoURL={candidate.player.photoURL ?? undefined}
            name={candidate.player.name}
          />
        )}
      </Card>
    </Animated.View>
  );
}

function DemoBadge() {
  return (
    <View style={{ backgroundColor: colors.surfaceCourt, borderColor: colors.borderStrong, borderRadius: radii.pill, borderWidth: 1, paddingHorizontal: 7, paddingVertical: 2 }}>
      <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 9, fontWeight: "800" }}>MUESTRA</Text>
    </View>
  );
}

function DemoNotice() {
  return (
    <View style={{ alignItems: "center", backgroundColor: colors.surfaceCourt, borderRadius: radii.md, flexDirection: "row", gap: spacing.sm, padding: spacing.sm }}>
      <Icon name="users" size={14} color={colors.textTertiary as string} />
      <Text style={{ ...typography.footnote, color: colors.textTertiary, flex: 1 }}>Perfil ilustrativo · sin acciones disponibles</Text>
    </View>
  );
}

/** Desktop/mobile action row — single-line CTAs, Waze brand badge, profile thumb. */
function CardActionBar({
  onProfile,
  onWaze,
  photoURL,
  name
}: {
  onProfile: () => void;
  onWaze?: () => void;
  photoURL?: string;
  name: string;
}) {
  return (
    <View
      style={{
        alignItems: "center",
        flexDirection: "row",
        flexWrap: "nowrap",
        gap: spacing.sm,
        marginTop: "auto"
      }}
    >
      <Pressable
        accessibilityLabel={`Ver perfil de ${name}`}
        onPress={onProfile}
        style={({ pressed }) => ({
          alignItems: "center",
          backgroundColor: pressed ? "rgba(198,241,53,0.22)" : "rgba(198,241,53,0.12)",
          borderColor: `${colors.neon}44`,
          borderRadius: radii.pill,
          borderWidth: 1,
          flex: 1,
          flexDirection: "row",
          gap: 8,
          height: 46,
          justifyContent: "center",
          minWidth: 0,
          paddingHorizontal: spacing.md
        })}
      >
        <Avatar name={name} photoURL={photoURL} size={26} />
        <Text
          numberOfLines={1}
          style={{
            ...typography.bodyEmphasized,
            color: colors.neon,
            flexShrink: 1,
            fontSize: 14,
            fontWeight: "800"
          }}
        >
          Ver perfil
        </Text>
      </Pressable>

      {onWaze ? (
        <Pressable
          accessibilityLabel="Cómo llegar con Waze"
          onPress={onWaze}
          style={({ pressed }) => ({
            alignItems: "center",
            backgroundColor: pressed ? "rgba(0,160,227,0.18)" : "rgba(0,160,227,0.1)",
            borderColor: "rgba(0,168,232,0.45)",
            borderRadius: radii.pill,
            borderWidth: 1,
            flex: 1.15,
            flexDirection: "row",
            gap: 8,
            height: 46,
            justifyContent: "center",
            minWidth: 0,
            paddingHorizontal: spacing.md
          })}
        >
          <View
            style={{
              borderRadius: 8,
              boxShadow: "0 4px 12px rgba(0,160,227,0.35)",
              overflow: "hidden"
            }}
          >
            <WazeLogo size={24} variant="brand" />
          </View>
          <Text
            numberOfLines={1}
            style={{
              ...typography.bodyEmphasized,
              color: colors.textPrimary,
              flexShrink: 1,
              fontSize: 14,
              fontWeight: "800"
            }}
          >
            Cómo llegar
          </Text>
        </Pressable>
      ) : null}
    </View>
  );
}

/** Anillo de compatibilidad estilo concepto ("86%"). */
function MatchScoreBadge({ score, compact = false }: { score: number; compact?: boolean }) {
  const { isLight } = useThemeMode();
  const pct = compatibilityPct(score);

  if (compact) {
    return (
      <Animated.View
        entering={FadeIn.delay(200).springify()}
        style={{
          backgroundColor: colors.accentFill,
          borderRadius: radii.pill,
          paddingHorizontal: spacing.sm,
          paddingVertical: 3
        }}
      >
        <Text style={{ ...broadcast.stat, color: colors.onAccentFill, fontSize: 13 }}>{pct}%</Text>
      </Animated.View>
    );
  }

  // En claro el neón es verde oscuro: sobre disco negro no contrasta, así que
  // el disco pasa a blanco con borde neón (misma lectura "broadcast LED").
  return (
    <Animated.View
      entering={FadeIn.delay(200).springify()}
      style={{
        alignItems: "center",
        backgroundColor: isLight ? "#FFFFFF" : "rgba(8,19,10,0.85)",
        borderColor: colors.neon,
        borderRadius: 999,
        borderWidth: 3,
        boxShadow: shadows.courtGlow,
        height: 58,
        justifyContent: "center",
        width: 58
      }}
    >
      <Text style={{ ...broadcast.stat, color: colors.neon, fontSize: 17, lineHeight: 19 }}>{pct}%</Text>
      <Text
        style={{
          ...typography.caption,
          color: colors.textSecondary,
          fontSize: 7,
          letterSpacing: 1,
          textTransform: "uppercase"
        }}
      >
        match
      </Text>
    </Animated.View>
  );
}

function MiniSignal({ label, value, accent = false }: { label: string; value: string; accent?: boolean }) {
  const { isLight } = useThemeMode();
  return (
    <View
      style={{
        backgroundColor: accent ? colors.courtLight : isLight ? "rgba(27,55,36,0.04)" : "rgba(234,243,228,0.055)",
        borderColor: accent ? `${colors.neon}33` : colors.border,
        borderRadius: radii.md,
        borderWidth: 1,
        flex: 1,
        paddingHorizontal: spacing.sm,
        paddingVertical: spacing.xs
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 10 }}>{label}</Text>
      <Text style={{ ...typography.caption, color: accent ? colors.neon : colors.textPrimary }} numberOfLines={1}>
        {value}
      </Text>
    </View>
  );
}

function ReasonPill({ reason, extra = 0 }: { reason: string; extra?: number }) {
  return (
    <View
      style={{
        alignItems: "center",
        alignSelf: "flex-start",
        backgroundColor: colors.courtLight,
        borderRadius: radii.pill,
        paddingHorizontal: spacing.sm,
        paddingVertical: 5,
        flexDirection: "row",
        gap: 4
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.court, fontWeight: "700" }}>
        {reason}
      </Text>
      {extra > 0 ? (
        <Text style={{ ...typography.footnote, color: colors.textSecondary, fontWeight: "600" }}>
          +{extra}
        </Text>
      ) : null}
    </View>
  );
}
