import { Image, type ImageSourcePropType, Text, View } from "react-native";
import { DIVISION_LABELS, DIVISION_META } from "@/data/rankings";
import { colors, radii, spacing, typography, useThemeMode } from "@/theme";
import type { Division } from "@/types";

const DIVISION_ICONS_DARK: Record<Division, ImageSourcePropType> = {
  novato: require("@/../assets/generated/divisions/novato.png"),
  d: require("@/../assets/generated/divisions/d.png"),
  c: require("@/../assets/generated/divisions/c.png"),
  b: require("@/../assets/generated/divisions/b.png"),
  a: require("@/../assets/generated/divisions/a.png")
};

const DIVISION_ICONS_LIGHT: Record<Division, ImageSourcePropType> = {
  novato: require("@/../assets/generated/divisions/novato-light.png"),
  d: require("@/../assets/generated/divisions/d-light.png"),
  c: require("@/../assets/generated/divisions/c-light.png"),
  b: require("@/../assets/generated/divisions/b-light.png"),
  a: require("@/../assets/generated/divisions/a-light.png")
};

export function divisionIcon(division: Division, light?: boolean): ImageSourcePropType {
  return light ? DIVISION_ICONS_LIGHT[division] : DIVISION_ICONS_DARK[division];
}

type Props = {
  division: Division;
  size?: number;
  showLabel?: boolean;
  active?: boolean;
};

/** Distinct Grok-generated badge per ranking circuit (Novato → A), theme-aware. */
export function DivisionBadge({ division, size = 40, showLabel = false, active = true }: Props) {
  const { isLight } = useThemeMode();
  const meta = DIVISION_META[division];
  const source = isLight ? DIVISION_ICONS_LIGHT[division] : DIVISION_ICONS_DARK[division];

  return (
    <View style={{ alignItems: "center", gap: 4, opacity: active ? 1 : 0.55 }}>
      <View
        style={{
          borderColor: active ? `${meta.accent}88` : colors.border,
          borderRadius: radii.md,
          borderWidth: 1.5,
          boxShadow: active ? `0 8px 22px -10px ${meta.accent}99` : undefined,
          height: size,
          overflow: "hidden",
          width: size
        }}
      >
        <Image source={source} style={{ height: size, width: size }} resizeMode="cover" />
      </View>
      {showLabel ? (
        <Text style={{ ...typography.footnote, color: active ? meta.accent : colors.textTertiary, fontWeight: "800" }}>
          {DIVISION_LABELS[division]}
        </Text>
      ) : null}
    </View>
  );
}

export function DivisionIdentity({ division, compact = false }: { division: Division; compact?: boolean }) {
  const { isLight } = useThemeMode();
  const meta = DIVISION_META[division];
  const source = isLight ? DIVISION_ICONS_LIGHT[division] : DIVISION_ICONS_DARK[division];

  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: isLight ? `${meta.accent}14` : `${meta.accent}18`,
        borderColor: `${meta.accent}55`,
        borderRadius: radii.pill,
        borderWidth: 1,
        flexDirection: "row",
        gap: spacing.sm,
        paddingHorizontal: spacing.md,
        paddingVertical: compact ? 6 : spacing.sm
      }}
    >
      <Image
        source={source}
        style={{ borderRadius: 10, height: compact ? 32 : 40, width: compact ? 32 : 40 }}
      />
      <View style={{ gap: 1 }}>
        <Text style={{ ...typography.footnote, color: isLight ? colors.court : meta.accent, fontWeight: "900", letterSpacing: 1 }}>
          {meta.circuit}
        </Text>
        <Text style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "700" }}>
          {meta.motto}
        </Text>
      </View>
    </View>
  );
}
