import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeInDown } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { Icon } from "@/components/icon";
import { StarRating } from "@/components/star-rating";
import { averageStars } from "@/lib/match-room";
import { broadcast, colors, radii, shadows, spacing, typography } from "@/theme";
import { MatchReview } from "@/types";

function timeAgo(iso: string) {
  const days = Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
  if (days <= 0) return "hoy";
  if (days === 1) return "ayer";
  if (days < 7) return `hace ${days} días`;
  if (days < 30) return `hace ${Math.floor(days / 7)} sem`;
  return `hace ${Math.floor(days / 30)} mes`;
}

/**
 * Notas del jugador — reseñas que otros rivales dejaron tras partidos validados.
 * Encabezado con promedio de estrellas + lista de comentarios.
 */
export function PlayerReviews({ reviews }: { reviews: MatchReview[] }) {
  const avg = averageStars(reviews);

  return (
    <View style={{ gap: spacing.md }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.courtDeep,
            borderColor: "rgba(198,241,53,0.20)",
            borderWidth: 1,
            borderRadius: radii.md,
            boxShadow: shadows.courtGlow,
            justifyContent: "center",
            minWidth: 72,
            paddingHorizontal: spacing.sm,
            paddingVertical: spacing.sm
          }}
        >
          {/* Placa courtDeep siempre oscura → lima fijo (colors.spotlight es oliva en claro). */}
          <Text style={{ ...broadcast.scoreboard, color: "#C6F135", fontSize: 34, lineHeight: 38 }}>
            {avg ? avg.toFixed(1) : "—"}
          </Text>
          <StarRating value={avg ?? 0} size={11} gap={1} color="#C6F135" />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Notas de rivales</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
            {reviews.length === 0
              ? "Aún sin reseñas de partidos."
              : `${reviews.length} ${reviews.length === 1 ? "reseña" : "reseñas"} de partidos validados`}
          </Text>
        </View>
      </View>

      {reviews.slice(0, 6).map((review, index) => (
        <Animated.View
          key={`${review.playerId}-${review.createdAt}`}
          entering={FadeInDown.delay(index * 60).springify().damping(18)}
          style={{
            backgroundColor: colors.surfaceElevated,
            borderColor: colors.border,
            borderRadius: radii.md,
            borderWidth: 1,
            gap: spacing.xs,
            padding: spacing.md
          }}
        >
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <Avatar name={review.playerName} size={28} />
            <Text style={{ ...typography.caption, color: colors.textPrimary, flex: 1, fontWeight: "700" }}>
              {review.playerName}
            </Text>
            <StarRating value={review.stars} size={13} gap={1} />
          </View>
          {review.comment ? (
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, lineHeight: 20 }}>
              “{review.comment}”
            </Text>
          ) : null}
          {review.skillRatings ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {([
                ["Servicio", review.skillRatings.serve],
                ["Derecha", review.skillRatings.forehand],
                ["Revés", review.skillRatings.backhand],
                ["Volea", review.skillRatings.volley],
                ["Consistencia", review.skillRatings.consistency]
              ] as Array<[string, number]>).map(([label, value]) => (
                <View key={label} style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: 7, paddingVertical: 3 }}>
                  <Text style={{ ...typography.footnote, color: colors.neon, fontSize: 10, fontWeight: "800" }}>
                    {label} {value}/10
                  </Text>
                </View>
              ))}
            </View>
          ) : null}
          <View style={{ alignItems: "center", flexDirection: "row", gap: 4 }}>
            <Icon name="clock" size={10} color={colors.textTertiary as string} />
            <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 11 }}>
              {timeAgo(review.createdAt)}
            </Text>
          </View>
        </Animated.View>
      ))}
    </View>
  );
}
