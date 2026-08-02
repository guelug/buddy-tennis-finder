import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeInDown } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { Icon } from "@/components/icon";
import { StarRating } from "@/components/star-rating";
import { averageStars } from "@/lib/match-room";
import { useI18n } from "@/lib/i18n";
import { broadcast, colors, radii, shadows, spacing, typography } from "@/theme";
import { MatchReview } from "@/types";

function timeAgoKey(iso: string, locale: string): { key: string; params?: Record<string, number> } {
  const days = Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
  if (days <= 0) return { key: "reviews.today" };
  if (days === 1) return { key: "reviews.yesterday" };
  if (days < 7) return { key: "reviews.daysAgo", params: { count: days } };
  if (days < 30) return { key: "reviews.weeksAgo", params: { count: Math.floor(days / 7) } };
  return { key: "reviews.monthsAgo", params: { count: Math.floor(days / 30) } };
}

function formatReviewLocaleDate(iso: string, locale: string) {
  try {
    return new Date(iso).toLocaleDateString(locale, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
  } catch {
    return new Date(iso).toISOString().slice(0, 16).replace("T", " ");
  }
}

/**
 * Valoraciones numéricas recibidas tras partidos validados.
 */
export function PlayerReviews({ reviews }: { reviews: MatchReview[] }) {
  const { t, locale } = useI18n();
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
          {/* La placa es courtDeep (oscura en los dos modos), así que va lima. */}
          <Text style={{ ...broadcast.scoreboard, color: colors.accentFill, fontSize: 34, lineHeight: 38 }}>
            {avg ? avg.toFixed(1) : "—"}
          </Text>
          <StarRating value={avg ?? 0} size={11} gap={1} color={colors.accentFill as string} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("profile.reviews.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
            {reviews.length === 0
              ? t("reviews.empty")
              : reviews.length === 1
                ? t("reviews.countOne")
                : t("reviews.countMany", { count: reviews.length })}
          </Text>
        </View>
      </View>

      {reviews.slice(0, 6).map((review, index) => (
        <Animated.View
          key={review.id ?? `${review.authorId}-${review.targetId}-${review.createdAt}`}
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
            <Avatar name={review.authorName} size={28} />
            <Text style={{ ...typography.caption, color: colors.textPrimary, flex: 1, fontWeight: "700" }}>
              {review.authorName}
            </Text>
            <StarRating value={review.stars} size={13} gap={1} />
          </View>
          {review.skillRatings ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {([
                [t("skills.serve"), review.skillRatings.serve],
                [t("skills.forehand"), review.skillRatings.forehand],
                [t("skills.backhand"), review.skillRatings.backhand],
                [t("skills.volley"), review.skillRatings.volley],
                [t("skills.consistency"), review.skillRatings.consistency]
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
              {(() => {
                const slot = timeAgoKey(review.createdAt, locale);
                return slot.params ? t(slot.key, slot.params) : t(slot.key);
              })()}
            </Text>
          </View>
        </Animated.View>
      ))}
    </View>
  );
}
