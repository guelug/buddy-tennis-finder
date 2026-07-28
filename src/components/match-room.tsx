import * as React from "react";
import { Alert, Pressable, Text, TextInput, View } from "react-native";
import Animated, {
  FadeIn,
  FadeInDown,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withSpring,
  withTiming
} from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import ViewShot, { captureRef, type ViewShotRef } from "react-native-view-shot";
import { Avatar } from "@/components/avatar";
import { BallDrop } from "@/components/ball-bounce";
import { Card } from "@/components/card";
import { Icon } from "@/components/icon";
import { StarRating } from "@/components/star-rating";
import {
  averageStars,
  disputeResult,
  reportResult,
  reviewTargets,
  roomAffordances,
  scoreLine,
  submitReview,
  validateResult
} from "@/lib/match-room";
import { shareMatchResultImage } from "@/lib/share";
import { broadcast, colors, radii, shadows, spacing, typography } from "@/theme";
import { MatchRoom, MatchRoomStatus, PlayerSkills, SetScore, TeamSide } from "@/types";

/**
 * Sala del partido — el corazón competitivo de la app.
 *
 * Flujo: el capitán registra el marcador → un jugador del equipo rival lo
 * valida (o disputa) → el partido queda cerrado y se abren las reseñas
 * (estrellas + 1 comentario por participante).
 */

// ---------------------------------------------------------------------------
// Config de estados
// ---------------------------------------------------------------------------

const STATUS_META: Record<
  MatchRoomStatus,
  { label: string; bg: string; fg: string }
> = {
  awaiting_result: { label: "Falta marcador", bg: colors.warningBg as string, fg: colors.warning as string },
  awaiting_validation: { label: "Por validar", bg: colors.infoBg as string, fg: colors.info as string },
  validated: { label: "Validado", bg: colors.successBg as string, fg: colors.success as string },
  disputed: { label: "En disputa", bg: colors.dangerBg as string, fg: colors.danger as string }
};

function formatLabel(format: MatchRoom["format"]) {
  return format === "singles" ? "Singles" : format === "doubles" ? "Dobles" : "Mixto";
}

function matchDate(iso: string) {
  return new Date(iso).toLocaleDateString("es-GT", { weekday: "short", day: "numeric", month: "short" });
}

function haptic(kind: "select" | "success" | "warning") {
  if (process.env.EXPO_OS !== "ios") return;
  if (kind === "select") Haptics.selectionAsync();
  else if (kind === "success") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  else Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
}

// ---------------------------------------------------------------------------
// CTA spotlight — el botón de los momentos de verdad
// ---------------------------------------------------------------------------

function SpotlightCta({
  label,
  onPress,
  disabled,
  icon,
  compact
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  icon?: React.ReactNode;
  compact?: boolean;
}) {
  const pressed = useSharedValue(0);
  const style = useAnimatedStyle(
    () => ({ transform: [{ scale: 1 - pressed.value * 0.05 }] }),
    []
  );

  return (
    <Animated.View style={style}>
      <Pressable
        onPress={onPress}
        disabled={disabled}
        onPressIn={() => {
          pressed.value = withSpring(1, { damping: 14, stiffness: 380 });
        }}
        onPressOut={() => {
          pressed.value = withSpring(0, { damping: 14, stiffness: 380 });
        }}
        accessibilityRole="button"
        style={{
          alignItems: "center",
          backgroundColor: colors.spotlight,
          borderRadius: radii.pill,
          boxShadow: disabled ? undefined : shadows.spotlightGlow,
          flexDirection: "row",
          gap: spacing.sm,
          height: compact ? 42 : 52,
          justifyContent: "center",
          opacity: disabled ? 0.5 : 1,
          paddingHorizontal: spacing.lg
        }}
      >
        {icon}
        <Text style={{ ...broadcast.jersey, color: colors.textOnBall, fontSize: 14, letterSpacing: 1, textTransform: "uppercase" }}>
          {label}
        </Text>
      </Pressable>
    </Animated.View>
  );
}

// ---------------------------------------------------------------------------
// Sello VALIDADO — animación de estampado
// ---------------------------------------------------------------------------

export function ValidationStamp({ delay = 0 }: { delay?: number }) {
  const scale = useSharedValue(2.2);
  const opacity = useSharedValue(0);

  React.useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration: 120 }));
    scale.value = withDelay(
      delay,
      withSequence(
        withTiming(0.92, { duration: 160 }),
        withSpring(1, { damping: 11, stiffness: 320 })
      )
    );
  }, [delay, scale, opacity]);

  const style = useAnimatedStyle(
    () => ({
      opacity: opacity.value,
      transform: [{ rotate: "-7deg" }, { scale: scale.value }]
    }),
    []
  );

  return (
    <Animated.View
      style={[
        style,
        {
          alignItems: "center",
          alignSelf: "center",
          borderColor: colors.success,
          borderRadius: radii.sm,
          borderWidth: 2.5,
          flexDirection: "row",
          gap: spacing.xs,
          paddingHorizontal: spacing.md,
          paddingVertical: 4
        }
      ]}
    >
      <Icon name="check-badge" size={16} color={colors.success as string} />
      <Text style={{ ...broadcast.jersey, color: colors.success, fontSize: 14, letterSpacing: 2 }}>
        VALIDADO
      </Text>
    </Animated.View>
  );
}

// ---------------------------------------------------------------------------
// Face-off — equipos frente a frente
// ---------------------------------------------------------------------------

function TeamColumn({
  room,
  side,
  highlight
}: {
  room: MatchRoom;
  side: TeamSide;
  highlight: boolean;
}) {
  const team = side === "A" ? room.teamA : room.teamB;

  return (
    <View style={{ alignItems: "center", flex: 1, gap: spacing.sm }}>
      <View style={{ flexDirection: "row" }}>
        {team.playerNames.map((name, index) => (
          <View
            key={name}
            style={{
              borderColor: highlight ? colors.spotlight : "transparent",
              borderRadius: 999,
              borderWidth: 2.5,
              marginLeft: index > 0 ? -14 : 0,
              boxShadow: highlight ? shadows.spotlightGlow : undefined
            }}
          >
            <Avatar name={name} size={team.playerNames.length > 1 ? 48 : 60} />
          </View>
        ))}
      </View>
      <View style={{ alignItems: "center", gap: 2 }}>
        {team.playerNames.map((name, index) => {
          const isCaptain = team.playerIds[index] === team.captainId;
          return (
            <View key={name} style={{ alignItems: "center", flexDirection: "row", gap: 4 }}>
              <Text
                style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "700", textAlign: "center" }}
                numberOfLines={1}
              >
                {name}
              </Text>
              {isCaptain ? (
                <View
                  style={{
                    backgroundColor: colors.courtLight,
                    borderRadius: 4,
                    paddingHorizontal: 4,
                    paddingVertical: 1
                  }}
                >
                  <Text style={{ ...broadcast.jersey, color: colors.court, fontSize: 9, letterSpacing: 0.5 }}>C</Text>
                </View>
              ) : null}
            </View>
          );
        })}
      </View>
      {highlight ? (
        <Animated.View entering={FadeIn.delay(250)} style={{ alignItems: "center", flexDirection: "row", gap: 4 }}>
          <Icon name="trophy" size={13} color={colors.gold as string} />
          <Text style={{ ...broadcast.jersey, color: colors.gold, fontSize: 11, letterSpacing: 1.4 }}>GANADOR</Text>
        </Animated.View>
      ) : null}
    </View>
  );
}

function FaceOff({ room }: { room: MatchRoom }) {
  const winner = room.status === "validated" ? room.result?.winner : undefined;

  return (
    <View style={{ alignItems: "flex-start", flexDirection: "row", gap: spacing.sm }}>
      <TeamColumn room={room} side="A" highlight={winner === "A"} />
      <View style={{ alignItems: "center", justifyContent: "center", minWidth: 52, paddingTop: spacing.md }}>
        <Text style={{ ...broadcast.rank, color: colors.textTertiary, fontSize: 26 }}>VS</Text>
      </View>
      <TeamColumn room={room} side="B" highlight={winner === "B"} />
    </View>
  );
}

function ResultShareCard({ room, clubName }: { room: MatchRoom; clubName?: string }) {
  const winner = room.result?.winner;
  const winnerNames = winner === "A" ? room.teamA.playerNames : room.teamB.playerNames;
  const score = room.result?.sets.map((set) => `${set.a}–${set.b}`).join("  ") ?? "";
  return (
    <View collapsable={false} style={{ aspectRatio: 4 / 5, backgroundColor: "#071B12", borderRadius: radii.xl, overflow: "hidden", padding: 24, width: "100%" }}>
      <View style={{ backgroundColor: "#C6F13522", borderRadius: 999, height: 260, position: "absolute", right: -100, top: -80, width: 260 }} />
      <View style={{ borderColor: "#C6F13533", borderRadius: 999, borderWidth: 2, bottom: -150, height: 360, left: -130, position: "absolute", width: 360 }} />
      <View style={{ borderColor: "#FFFFFF16", borderWidth: 1, bottom: 28, left: 28, position: "absolute", right: 28, top: 92 }} />
      <View style={{ backgroundColor: "#FFFFFF16", height: 1, left: 28, position: "absolute", right: 28, top: "50%" }} />
      <View style={{ alignItems: "center", flex: 1, justifyContent: "space-between" }}>
        <View style={{ alignItems: "center", gap: 3 }}>
          <Text style={{ ...broadcast.jersey, color: "#C6F135", fontSize: 12, letterSpacing: 2.4 }}>MATCHPOINT TENNIS</Text>
          <Text style={{ ...typography.footnote, color: "#FFFFFF99" }}>{matchDate(room.playedAt)} · {clubName ?? "Club"}</Text>
        </View>
        <View style={{ alignItems: "center", gap: 10, width: "100%" }}>
          <View style={{ backgroundColor: "#C6F135", borderRadius: radii.pill, paddingHorizontal: 14, paddingVertical: 5 }}>
            <Text style={{ ...broadcast.jersey, color: "#071B12", fontSize: 11, letterSpacing: 1.7 }}>RESULTADO FINAL</Text>
          </View>
          <Text numberOfLines={2} style={{ ...broadcast.hero, color: "white", fontSize: 29, lineHeight: 32, textAlign: "center" }}>{room.teamA.playerNames.join(" + ")}</Text>
          <Text style={{ ...broadcast.jersey, color: "#FFFFFF77", fontSize: 15, letterSpacing: 3 }}>VS</Text>
          <Text numberOfLines={2} style={{ ...broadcast.hero, color: "white", fontSize: 29, lineHeight: 32, textAlign: "center" }}>{room.teamB.playerNames.join(" + ")}</Text>
        </View>
        <View style={{ alignItems: "center", gap: 7 }}>
          <Text style={{ ...broadcast.scoreboard, color: "#C6F135", fontSize: 38, lineHeight: 42 }}>{score}</Text>
          <Text style={{ ...broadcast.jersey, color: "#FFD76A", fontSize: 12, letterSpacing: 1.5 }}>🏆 {winnerNames.join(" + ")} GANA</Text>
          <Text style={{ ...typography.footnote, color: "#FFFFFF88" }}>Encuentra rival. Juega. Comparte.</Text>
        </View>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Marcador — chips de sets estilo scoreboard
// ---------------------------------------------------------------------------

function SetPips({ sets, winner }: { sets: SetScore[]; winner?: TeamSide }) {
  return (
    <View style={{ flexDirection: "row", gap: spacing.sm, justifyContent: "center" }}>
      {sets.map((set, index) => {
        const setWinner: TeamSide = set.a === set.b ? (winner ?? "A") : set.a > set.b ? "A" : "B";
        return (
          <BallDrop key={`${index}-${set.a}-${set.b}`} delay={index * 90}>
            <View
              style={{
                alignItems: "center",
                backgroundColor: colors.courtDeep,
                borderColor: setWinner === "A" ? "rgba(198,241,53,0.40)" : colors.border,
                borderWidth: 1,
                borderRadius: radii.sm,
                minWidth: 58,
                paddingHorizontal: spacing.sm,
                paddingVertical: spacing.xs,
                boxShadow: setWinner === "A" ? shadows.courtGlow : undefined
              }}
            >
              <Text style={{ ...broadcast.scoreboard, color: colors.textOnCourt, fontSize: 26, lineHeight: 30 }}>
                {set.a}
                <Text style={{ color: "rgba(255,255,255,0.45)" }}>–</Text>
                {set.b}
              </Text>
              <Text style={{ ...broadcast.jersey, color: setWinner === "A" ? "#C6F135" : "rgba(255,255,255,0.6)", fontSize: 8, letterSpacing: 1 }}>
                SET {index + 1}
              </Text>
            </View>
          </BallDrop>
        );
      })}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Stepper de estado — Resultado → Validación → Cerrado
// ---------------------------------------------------------------------------

function PulsingDot({ color }: { color: string }) {
  const pulse = useSharedValue(0);

  React.useEffect(() => {
    pulse.value = withRepeat(withTiming(1, { duration: 900 }), -1, true);
  }, [pulse]);

  const halo = useAnimatedStyle(
    () => ({
      opacity: 0.5 - pulse.value * 0.4,
      transform: [{ scale: 1 + pulse.value * 0.9 }]
    }),
    []
  );

  return (
    <View style={{ alignItems: "center", height: 14, justifyContent: "center", width: 14 }}>
      <Animated.View
        style={[halo, { backgroundColor: color, borderRadius: 999, height: 14, position: "absolute", width: 14 }]}
      />
      <View style={{ backgroundColor: color, borderRadius: 999, height: 10, width: 10 }} />
    </View>
  );
}

function StatusStepper({ status }: { status: MatchRoomStatus }) {
  const steps = ["Marcador", "Validación", "Cerrado"];
  const current = status === "awaiting_result" ? 0 : status === "awaiting_validation" || status === "disputed" ? 1 : 2;
  const disputed = status === "disputed";
  const doneColor = colors.court as string;
  const activeColor = disputed ? (colors.danger as string) : (colors.court as string);

  return (
    <View style={{ gap: spacing.xs }}>
      <View style={{ alignItems: "center", flexDirection: "row" }}>
        {steps.map((_, index) => {
          const done = index < current || status === "validated";
          const active = index === current && status !== "validated";
          return (
            <React.Fragment key={index}>
              {index > 0 ? (
                <View style={{ backgroundColor: index <= current ? doneColor : colors.border, flex: 1, height: 2.5 }} />
              ) : null}
              {active ? (
                <PulsingDot color={activeColor} />
              ) : (
                <View
                  style={{
                    alignItems: "center",
                    backgroundColor: done ? doneColor : (colors.border as string),
                    borderRadius: 999,
                    height: 14,
                    justifyContent: "center",
                    width: 14
                  }}
                >
                  {done ? <Icon name="check" size={9} color="#FFFFFF" /> : null}
                </View>
              )}
            </React.Fragment>
          );
        })}
      </View>
      <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
        {steps.map((step, index) => (
          <Text
            key={step}
            style={{
              ...broadcast.jersey,
              color: index === current && disputed ? colors.danger : index <= current ? colors.court : colors.textTertiary,
              fontSize: 10,
              letterSpacing: 1
            }}
          >
            {index === 1 && disputed ? "EN DISPUTA" : step.toUpperCase()}
          </Text>
        ))}
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Editor de resultado (capitán)
// ---------------------------------------------------------------------------

function ScoreStepper({ value, onChange }: { value: number; onChange: (next: number) => void }) {
  const bump = (delta: number) => {
    haptic("select");
    onChange(Math.min(7, Math.max(0, value + delta)));
  };

  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
      <StepButton label="−" onPress={() => bump(-1)} />
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.courtDeep,
          borderColor: colors.border,
          borderWidth: 1,
          borderRadius: radii.xs,
          minWidth: 44,
          paddingVertical: 2
        }}
      >
        <Text
          key={value}
          style={{ ...broadcast.scoreboard, color: colors.textOnCourt, fontSize: 28, lineHeight: 34 }}
        >
          {value}
        </Text>
      </View>
      <StepButton label="+" onPress={() => bump(1)} />
    </View>
  );
}

function StepButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      hitSlop={6}
      style={({ pressed }) => ({
        alignItems: "center",
        backgroundColor: pressed ? colors.courtLight : colors.surfaceElevated,
        borderColor: colors.borderStrong,
        borderRadius: 999,
        borderWidth: 1,
        height: 34,
        justifyContent: "center",
        width: 34
      })}
    >
      <Text style={{ ...typography.headline, color: colors.court, fontSize: 18, lineHeight: 20 }}>{label}</Text>
    </Pressable>
  );
}

function ResultEditor({
  room,
  busy,
  onSubmit
}: {
  room: MatchRoom;
  busy: boolean;
  onSubmit: (winner: TeamSide, sets: SetScore[]) => void;
}) {
  const [sets, setSets] = React.useState<SetScore[]>(
    room.result?.sets.map((set) => ({ ...set })) ?? [{ a: 0, b: 0 }]
  );
  const [winner, setWinner] = React.useState<TeamSide | null>(room.result?.winner ?? null);

  const teamLabel = (side: TeamSide) =>
    (side === "A" ? room.teamA : room.teamB).playerNames.join(" + ");

  const updateSet = (index: number, key: "a" | "b", value: number) => {
    setSets((prev) => prev.map((set, i) => (i === index ? { ...set, [key]: value } : set)));
  };

  return (
    <Animated.View entering={FadeInDown.springify().damping(18)} style={{ gap: spacing.base }}>
      <View style={{ gap: spacing.sm }}>
        <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 11, letterSpacing: 1.2 }}>
          ¿QUIÉN GANÓ?
        </Text>
        <View style={{ flexDirection: "row", gap: spacing.sm }}>
          {(["A", "B"] as TeamSide[]).map((side) => {
            const active = winner === side;
            return (
              <Pressable
                key={side}
                onPress={() => {
                  haptic("select");
                  setWinner(side);
                }}
                style={{
                  alignItems: "center",
                  backgroundColor: active ? colors.court : colors.surfaceElevated,
                  borderColor: active ? colors.court : colors.borderStrong,
                  borderRadius: radii.md,
                  borderWidth: 1.5,
                  flex: 1,
                  flexDirection: "row",
                  gap: spacing.xs,
                  justifyContent: "center",
                  paddingHorizontal: spacing.sm,
                  paddingVertical: spacing.md,
                  boxShadow: active ? shadows.courtGlow : undefined
                }}
              >
                <Icon name="trophy" size={14} color={(active ? colors.textOnBall : colors.textTertiary) as string} />
                <Text
                  style={{
                    ...typography.caption,
                    color: active ? colors.textOnBall : colors.textSecondary,
                    fontWeight: "800"
                  }}
                  numberOfLines={1}
                >
                  {teamLabel(side)}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </View>

      <View style={{ gap: spacing.sm }}>
        <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 11, letterSpacing: 1.2 }}>
          MARCADOR POR SET
        </Text>
        {sets.map((set, index) => (
          <View key={index} style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
            <Text style={{ ...broadcast.jersey, color: colors.textTertiary, fontSize: 11, width: 40 }}>
              SET {index + 1}
            </Text>
            <ScoreStepper value={set.a} onChange={(value) => updateSet(index, "a", value)} />
            <Text style={{ ...broadcast.rank, color: colors.textTertiary, fontSize: 18 }}>–</Text>
            <ScoreStepper value={set.b} onChange={(value) => updateSet(index, "b", value)} />
            {sets.length > 1 ? (
              <Pressable
                hitSlop={8}
                onPress={() => setSets((prev) => prev.filter((_, i) => i !== index))}
              >
                <Text style={{ ...typography.caption, color: colors.danger, fontWeight: "800" }}>✕</Text>
              </Pressable>
            ) : null}
          </View>
        ))}
        {sets.length < 5 ? (
          <Pressable
            onPress={() => setSets((prev) => [...prev, { a: 0, b: 0 }])}
            style={{ alignSelf: "flex-start" }}
          >
            <Text style={{ ...typography.caption, color: colors.hardCourt, fontWeight: "700" }}>
              + Agregar set
            </Text>
          </Pressable>
        ) : null}
      </View>

      <SpotlightCta
        label={busy ? "Enviando..." : "Enviar resultado"}
        disabled={busy || winner === null}
        icon={<Icon name="send" size={16} color={colors.textOnBall as string} />}
        onPress={() => {
          if (winner) onSubmit(winner, sets);
        }}
      />
      <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        El equipo rival deberá confirmar el marcador para que cuente en el ranking.
      </Text>
    </Animated.View>
  );
}

// ---------------------------------------------------------------------------
// Reseñas
// ---------------------------------------------------------------------------

function ReviewComposer({
  targets,
  reviews,
  busy,
  onSubmit
}: {
  targets: Array<{ id: string; name: string }>;
  reviews: MatchRoom["reviews"];
  busy: boolean;
  onSubmit: (targetId: string, stars: number, skillRatings: PlayerSkills) => void;
}) {
  const firstPending = targets.find((target) => !reviews.some((review) => review.targetId === target.id));
  const [targetId, setTargetId] = React.useState(firstPending?.id ?? targets[0]?.id ?? "");
  const selectedTarget = targets.find((target) => target.id === targetId);
  const existing = reviews.find((review) => review.targetId === targetId);
  const [stars, setStars] = React.useState(existing?.stars ?? 0);
  const [skillRatings, setSkillRatings] = React.useState<PlayerSkills>(
    existing?.skillRatings ?? { consistency: 7, forehand: 7, backhand: 7, serve: 7, volley: 7 }
  );

  const selectTarget = (nextTargetId: string) => {
    const nextReview = reviews.find((review) => review.targetId === nextTargetId);
    setTargetId(nextTargetId);
    setStars(nextReview?.stars ?? 0);
    setSkillRatings(nextReview?.skillRatings ?? { consistency: 7, forehand: 7, backhand: 7, serve: 7, volley: 7 });
    haptic("select");
  };

  return (
    <View
      style={{
        backgroundColor: colors.surfaceCourt,
        borderColor: colors.border,
        borderRadius: radii.md,
        borderWidth: 1,
        gap: spacing.md,
        padding: spacing.base
      }}
    >
      <View style={{ gap: spacing.sm }}>
        <Text style={{ ...typography.caption, color: colors.textSecondary, textAlign: "center" }}>
          ¿A quién quieres valorar?
        </Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm, justifyContent: "center" }}>
          {targets.map((target) => {
            const selected = target.id === targetId;
            const completed = reviews.some((review) => review.targetId === target.id);
            return (
              <Pressable
                key={target.id}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                onPress={() => selectTarget(target.id)}
                style={{
                  alignItems: "center",
                  backgroundColor: selected ? colors.courtLight : colors.surface,
                  borderColor: selected ? colors.neon : colors.border,
                  borderRadius: radii.pill,
                  borderWidth: 1,
                  flexDirection: "row",
                  gap: spacing.xs,
                  paddingHorizontal: spacing.md,
                  paddingVertical: spacing.sm
                }}
              >
                <Avatar name={target.name} size={24} />
                <Text style={{ ...typography.footnote, color: selected ? colors.neon : colors.textPrimary, fontWeight: "800" }}>
                  {target.name}
                </Text>
                {completed ? <Icon name="check-badge" size={13} color={colors.success as string} /> : null}
              </Pressable>
            );
          })}
        </View>
      </View>
      <View style={{ alignItems: "center", gap: spacing.sm }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
          {existing ? `Tu valoración de ${selectedTarget?.name ?? "esta persona"}` : `¿Cómo fue jugar con ${selectedTarget?.name ?? "esta persona"}?`}
        </Text>
        <StarRating value={stars} onChange={setStars} size={34} gap={8} />
      </View>
      <View style={{ gap: spacing.sm }}>
        <Text style={{ ...typography.caption, color: colors.textSecondary, textAlign: "center" }}>
          Puntúa a {selectedTarget?.name ?? "esta persona"} · 1 a 10
        </Text>
        {([
          ["serve", "Servicio"],
          ["forehand", "Derecha"],
          ["backhand", "Revés"],
          ["volley", "Volea"],
          ["consistency", "Consistencia"]
        ] as Array<[keyof PlayerSkills, string]>).map(([key, label]) => (
          <SkillScoreInput
            key={key}
            label={label}
            value={skillRatings[key]}
            onChange={(value) => setSkillRatings((current) => ({ ...current, [key]: value }))}
          />
        ))}
      </View>
      <SpotlightCta
        compact
        label={busy ? "Publicando..." : existing ? "Actualizar valoración" : "Publicar valoración"}
        disabled={busy || stars === 0 || !targetId}
        onPress={() => onSubmit(targetId, stars, skillRatings)}
      />
      <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        Una valoración por persona y partido · solo participantes.
      </Text>
    </View>
  );
}

function SkillScoreInput({ label, value, onChange }: { label: string; value: number; onChange: (value: number) => void }) {
  return (
    <View style={{ gap: 2 }}>
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ ...typography.footnote, color: colors.textPrimary, fontWeight: "700" }}>{label}</Text>
        <View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.pill, minWidth: 34, paddingHorizontal: 8, paddingVertical: 2 }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontVariant: ["tabular-nums"], fontWeight: "900" }}>{value}</Text>
        </View>
      </View>
      <View style={{ flexDirection: "row", gap: 3 }}>
        {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((score) => (
          <Pressable
            key={score}
            accessibilityRole="button"
            accessibilityState={{ selected: score === value }}
            accessibilityLabel={`${label}: ${score} de 10`}
            onPress={() => {
              onChange(score);
              haptic("select");
            }}
            style={{
              alignItems: "center",
              backgroundColor: score <= value ? colors.courtLight : colors.surface,
              borderColor: score === value ? colors.neon : colors.border,
              borderRadius: 7,
              borderWidth: 1,
              flex: 1,
              justifyContent: "center",
              minHeight: 32
            }}
          >
            <Text style={{ ...typography.footnote, color: score <= value ? colors.neon : colors.textTertiary, fontSize: 10, fontWeight: "800" }}>
              {score}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function ReviewList({ room, currentPlayerId }: { room: MatchRoom; currentPlayerId?: string }) {
  if (room.reviews.length === 0) {
    return (
      <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        Aún no hay reseñas de este partido.
      </Text>
    );
  }

  return (
    <View style={{ gap: spacing.sm }}>
      {room.reviews.map((review, index) => (
        <Animated.View
          key={review.id ?? `${review.authorId}-${review.targetId}`}
          entering={FadeInDown.delay(index * 70).springify().damping(18)}
          style={{
            backgroundColor: colors.surfaceElevated,
            borderColor: review.authorId === currentPlayerId ? `${colors.court}44` : colors.border,
            borderRadius: radii.md,
            borderWidth: 1,
            gap: spacing.sm,
            padding: spacing.md
          }}
        >
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <Avatar name={review.authorName} size={30} />
            <Text style={{ ...typography.caption, color: colors.textPrimary, flex: 1, fontWeight: "700" }}>
              {review.authorName}
              {review.authorId === currentPlayerId ? " (tú)" : ""}
              <Text style={{ color: colors.textTertiary }}> → {review.targetName}</Text>
            </Text>
            <StarRating value={review.stars} size={15} gap={2} />
          </View>
        </Animated.View>
      ))}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Sheet principal
// ---------------------------------------------------------------------------

export function MatchRoomSheet({
  room,
  currentPlayerId,
  clubName,
  onRoomChange,
  onClose
}: {
  room: MatchRoom;
  currentPlayerId?: string;
  clubName?: string;
  onRoomChange: (room: MatchRoom) => void;
  onClose: () => void;
}) {
  const [busy, setBusy] = React.useState<"report" | "validate" | "dispute" | "review" | null>(null);
  const [sharing, setSharing] = React.useState(false);
  const resultCardRef = React.useRef<ViewShotRef>(null);
  const a = roomAffordances(room, currentPlayerId);
  const meta = STATUS_META[room.status];

  const run = async (
    kind: NonNullable<typeof busy>,
    action: () => Promise<MatchRoom>,
    okHaptic: "success" | "warning" = "success"
  ) => {
    setBusy(kind);
    try {
      const updated = await action();
      haptic(okHaptic);
      onRoomChange(updated);
    } catch (error) {
      Alert.alert("No se pudo completar", error instanceof Error ? error.message : "Intenta de nuevo.");
    } finally {
      setBusy(null);
    }
  };

  return (
    <View style={{ gap: spacing.lg }}>
      {/* Header */}
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <View style={{ gap: 2 }}>
          <Text style={{ ...broadcast.jersey, color: colors.court, fontSize: 12, letterSpacing: 2 }}>
            SALA DEL PARTIDO
          </Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
            {matchDate(room.playedAt)} · {clubName ?? "Club"} · {formatLabel(room.format)}
          </Text>
        </View>
        <View
          style={{
            backgroundColor: meta.bg,
            borderColor: `${meta.fg}33`,
            borderRadius: radii.pill,
            borderWidth: 1,
            paddingHorizontal: spacing.md,
            paddingVertical: spacing.xs
          }}
        >
          <Text style={{ ...typography.footnote, color: meta.fg, fontWeight: "800" }}>{meta.label}</Text>
        </View>
      </View>

      <FaceOff room={room} />

      {room.result && !(a.canReport && room.status === "disputed") ? (
        <SetPips sets={room.result.sets} winner={room.result.winner} />
      ) : null}

      {room.status === "validated" ? <ValidationStamp /> : null}

      {room.status === "validated" && room.result ? (
        <View style={{ gap: spacing.sm }}>
          <ViewShot ref={resultCardRef} options={{ format: "png", quality: 1 }}>
            <ResultShareCard room={room} clubName={clubName} />
          </ViewShot>
          <SpotlightCta
            label={sharing ? "Preparando imagen..." : "Compartir resultado"}
            disabled={sharing}
            icon={<Icon name="send" size={16} color={colors.textOnBall as string} />}
            onPress={async () => {
              if (sharing || !resultCardRef.current) return;
              setSharing(true);
              try {
                const uri = await captureRef(resultCardRef, { format: "png", quality: 1, width: 1080, height: 1350 });
                const score = room.result?.sets.map((set) => `${set.a}-${set.b}`).join(", ") ?? "";
                await shareMatchResultImage(uri, `${room.teamA.playerNames.join(" + ")} vs ${room.teamB.playerNames.join(" + ")} · ${score}`);
              } catch (error) {
                Alert.alert("No se pudo compartir", error instanceof Error ? error.message : "Inténtalo de nuevo.");
              } finally {
                setSharing(false);
              }
            }}
          />
          <Text style={{ ...typography.footnote, color: colors.textSecondary, textAlign: "center" }}>Imagen 4:5 lista para Instagram, WhatsApp y otras redes.</Text>
        </View>
      ) : null}

      <StatusStepper status={room.status} />

      {/* Zona de acción según estado */}
      {room.status === "awaiting_result" || (room.status === "disputed" && a.canReport) ? (
        a.canReport ? (
          <>
            {room.status === "disputed" ? (
              <DisputeBanner text="El rival disputó el marcador. Corrígelo y vuelve a enviarlo." />
            ) : null}
            <ResultEditor
              room={room}
              busy={busy === "report"}
              onSubmit={(winner, sets) =>
                run("report", () => reportResult(room.id, currentPlayerId ?? "", { winner, sets }))
              }
            />
          </>
        ) : (
          <WaitingHint
            text={`El capitán (${captainNames(room)}) registra el marcador. Te avisaremos para validarlo.`}
          />
        )
      ) : null}

      {room.status === "disputed" && !a.canReport ? (
        <DisputeBanner text="Marcador en disputa — el capitán que lo registró debe corregirlo." />
      ) : null}

      {room.status === "awaiting_validation" ? (
        a.canValidate ? (
          <Animated.View entering={FadeInDown.springify().damping(18)} style={{ gap: spacing.sm }}>
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, textAlign: "center" }}>
              {room.result?.reportedByName} registró este marcador. ¿Es correcto?
            </Text>
            <SpotlightCta
              label={busy === "validate" ? "Confirmando..." : "Confirmar resultado"}
              disabled={busy !== null}
              icon={<Icon name="check-badge" size={16} color={colors.textOnBall as string} />}
              onPress={() => run("validate", () => validateResult(room.id, currentPlayerId ?? ""))}
            />
            <Pressable
              disabled={busy !== null}
              onPress={() =>
                run("dispute", () => disputeResult(room.id, currentPlayerId ?? ""), "warning")
              }
              style={{ alignItems: "center", paddingVertical: spacing.sm }}
            >
              <Text style={{ ...typography.caption, color: colors.danger, fontWeight: "700" }}>
                {busy === "dispute" ? "Enviando..." : "No es correcto — disputar"}
              </Text>
            </Pressable>
          </Animated.View>
        ) : (
          <WaitingHint text="Esperando que alguien del equipo rival confirme el marcador…" />
        )
      ) : null}

      {/* Reseñas — solo con partido validado */}
      {room.status === "validated" ? (
        <View style={{ gap: spacing.md }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <View style={{ backgroundColor: colors.courtLine, flex: 1, height: 1 }} />
            <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 11, letterSpacing: 1.6 }}>
              RESEÑAS DEL PARTIDO
            </Text>
            <View style={{ backgroundColor: colors.courtLine, flex: 1, height: 1 }} />
          </View>

          {a.canReview ? (
            <ReviewComposer
              targets={reviewTargets(room, currentPlayerId ?? "")}
              reviews={a.myReviews}
              busy={busy === "review"}
              onSubmit={(targetId, stars, skillRatings) =>
                run("review", () => submitReview(room.id, currentPlayerId ?? "", { targetId, stars, skillRatings }))
              }
            />
          ) : null}

          <ReviewList room={room} currentPlayerId={currentPlayerId} />
        </View>
      ) : null}

      <Pressable onPress={onClose} style={{ alignItems: "center", paddingVertical: spacing.xs }}>
        <Text style={{ ...typography.caption, color: colors.textSecondary, fontWeight: "700" }}>Cerrar</Text>
      </Pressable>
    </View>
  );
}

function WaitingHint({ text }: { text: string }) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.surfaceCourt,
        borderRadius: radii.md,
        flexDirection: "row",
        gap: spacing.sm,
        padding: spacing.base
      }}
    >
      <PulsingDot color={colors.warning as string} />
      <Text style={{ ...typography.body, color: colors.textSecondary, flex: 1, fontSize: 14, lineHeight: 20 }}>
        {text}
      </Text>
    </View>
  );
}

function DisputeBanner({ text }: { text: string }) {
  return (
    <View
      style={{
        backgroundColor: colors.dangerBg,
        borderColor: `${colors.danger}33`,
        borderRadius: radii.md,
        borderWidth: 1,
        padding: spacing.md
      }}
    >
      <Text style={{ ...typography.caption, color: colors.danger, fontWeight: "700", lineHeight: 18 }}>{text}</Text>
    </View>
  );
}

function captainNames(room: MatchRoom) {
  const captains: string[] = [];
  const indexA = room.teamA.playerIds.indexOf(room.teamA.captainId);
  if (indexA >= 0) captains.push(room.teamA.playerNames[indexA]);
  const indexB = room.teamB.playerIds.indexOf(room.teamB.captainId);
  if (indexB >= 0) captains.push(room.teamB.playerNames[indexB]);
  return captains.join(" o ");
}

// ---------------------------------------------------------------------------
// Card compacta para listas
// ---------------------------------------------------------------------------

export function MatchRoomCard({
  room,
  currentPlayerId,
  clubName,
  index = 0,
  onOpen
}: {
  room: MatchRoom;
  currentPlayerId?: string;
  clubName?: string;
  index?: number;
  onOpen: (room: MatchRoom) => void;
}) {
  const a = roomAffordances(room, currentPlayerId);
  const meta = STATUS_META[room.status];
  const line = scoreLine(room);
  const stars = averageStars(room.reviews);

  const ctaLabel =
    a.pendingAction === "report"
      ? "Registrar resultado"
      : a.pendingAction === "validate"
        ? "Validar resultado"
        : a.pendingAction === "review"
          ? "Calificar partido"
          : null;

  const youWon =
    room.status === "validated" && !!a.side && room.result?.winner === a.side;

  return (
    <BallDrop delay={index * 70}>
      <Pressable onPress={() => onOpen(room)}>
        <Card
          variant="elevated"
          style={{
            borderColor: a.pendingAction ? `${colors.spotlightDim}66` : colors.border,
            boxShadow: a.pendingAction ? shadows.spotlightGlow : undefined
          }}
        >
          <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
            <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
              {matchDate(room.playedAt)} · {clubName ?? "Club"} · {formatLabel(room.format)}
            </Text>
            <View
              style={{
                backgroundColor: meta.bg,
                borderRadius: radii.pill,
                paddingHorizontal: spacing.sm,
                paddingVertical: 3
              }}
            >
              <Text style={{ ...typography.footnote, color: meta.fg, fontSize: 11, fontWeight: "800" }}>
                {meta.label}
              </Text>
            </View>
          </View>

          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
            <View style={{ flex: 1, gap: 2 }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 15 }} numberOfLines={1}>
                {room.teamA.playerNames.join(" + ")}
              </Text>
              <Text style={{ ...broadcast.jersey, color: colors.textTertiary, fontSize: 10, letterSpacing: 1 }}>
                VS
              </Text>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 15 }} numberOfLines={1}>
                {room.teamB.playerNames.join(" + ")}
              </Text>
            </View>
            {line ? (
              <View style={{ alignItems: "flex-end", gap: 4 }}>
                <Text style={{ ...broadcast.stat, color: colors.court, fontSize: 20 }}>{line}</Text>
                {room.status === "validated" ? (
                  <View
                    style={{
                      backgroundColor: youWon ? colors.successBg : colors.surfaceElevated,
                      borderRadius: radii.pill,
                      paddingHorizontal: spacing.sm,
                      paddingVertical: 2
                    }}
                  >
                    <Text
                      style={{
                        ...typography.footnote,
                        color: youWon ? colors.success : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: "800"
                      }}
                    >
                      {youWon ? "Victoria" : a.side ? "Derrota" : "Cerrado"}
                    </Text>
                  </View>
                ) : null}
              </View>
            ) : null}
          </View>

          {stars !== null ? (
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <StarRating value={stars} size={14} gap={2} />
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
                {stars.toFixed(1)} · {room.reviews.length}{" "}
                {room.reviews.length === 1 ? "reseña" : "reseñas"}
              </Text>
            </View>
          ) : null}

          {ctaLabel ? (
            <SpotlightCta compact label={ctaLabel} onPress={() => onOpen(room)} />
          ) : (
            <View style={{ alignItems: "center", flexDirection: "row", gap: 4, justifyContent: "flex-end" }}>
              <Text style={{ ...typography.footnote, color: colors.textSecondary, fontWeight: "600" }}>
                Ver sala
              </Text>
              <Icon name="chevron-right" size={12} color={colors.textSecondary as string} />
            </View>
          )}
        </Card>
      </Pressable>
    </BallDrop>
  );
}
