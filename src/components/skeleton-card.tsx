import { View } from "react-native";
import { Skeleton, SkeletonCircle } from "@/components/skeleton";
import { Card } from "@/components/card";
import { colors, radii, spacing } from "@/theme";

type SkeletonLayout = "player" | "match" | "ranking" | "hero" | "text";

type SkeletonCardProps = {
  layout?: SkeletonLayout;
  count?: number;
};

/** Skeletons estructurados para cards típicas de la app. */
export function SkeletonCard({ layout = "text", count = 1 }: SkeletonCardProps) {
  const renderItem = () => {
    switch (layout) {
      case "player":
        return (
          <Card variant="elevated" style={{ flexDirection: "row", gap: spacing.md, alignItems: "center" }}>
            <SkeletonCircle size={56} />
            <View style={{ flex: 1, gap: spacing.xs }}>
              <Skeleton width="55%" height={18} />
              <Skeleton width="35%" height={14} />
              <View style={{ flexDirection: "row", gap: spacing.xs, marginTop: spacing.xs }}>
                <Skeleton width={56} height={22} borderRadius={radii.pill} />
                <Skeleton width={72} height={22} borderRadius={radii.pill} />
              </View>
            </View>
          </Card>
        );
      case "match":
        return (
          <Card variant="elevated">
            <View style={{ flexDirection: "row", gap: spacing.md, alignItems: "center" }}>
              <SkeletonCircle size={48} />
              <View style={{ flex: 1, gap: spacing.xs }}>
                <Skeleton width="45%" height={18} />
                <Skeleton width="60%" height={14} />
              </View>
              <Skeleton width={80} height={26} borderRadius={radii.pill} />
            </View>
            <View style={{ flexDirection: "row", gap: spacing.sm, marginTop: spacing.md }}>
              <Skeleton height={40} borderRadius={radii.pill} style={{ flex: 1 }} />
              <Skeleton height={40} borderRadius={radii.pill} style={{ flex: 1 }} />
            </View>
          </Card>
        );
      case "ranking":
        return (
          <View style={{ flexDirection: "row", gap: spacing.md, alignItems: "center", paddingVertical: spacing.sm }}>
            <Skeleton width={24} height={18} />
            <SkeletonCircle size={36} />
            <View style={{ flex: 1, gap: spacing.xs }}>
              <Skeleton width="50%" height={16} />
            </View>
            <Skeleton width={72} height={22} borderRadius={radii.pill} />
          </View>
        );
      case "hero":
        return (
          <View
            style={{
              backgroundColor: colors.courtLight,
              borderRadius: radii.xl,
              padding: spacing.lg,
              gap: spacing.md
            }}
          >
            <Skeleton width="40%" height={14} />
            <Skeleton width="75%" height={32} />
            <Skeleton width="90%" height={18} />
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              <Skeleton height={54} borderRadius={radii.pill} style={{ flex: 1 }} />
              <Skeleton height={54} borderRadius={radii.pill} style={{ flex: 1 }} />
            </View>
          </View>
        );
      default:
        return (
          <Card variant="elevated">
            <Skeleton width="60%" height={18} />
            <Skeleton width="90%" height={14} style={{ marginTop: spacing.xs }} />
          </Card>
        );
    }
  };

  return (
    <View style={{ gap: spacing.sm }}>
      {Array.from({ length: count }).map((_, index) => (
        <View key={index}>{renderItem()}</View>
      ))}
    </View>
  );
}
