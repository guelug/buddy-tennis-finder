import * as React from "react";
import { Text, View } from "react-native";
import { colors, radii, spacing, typography } from "@/theme";

type MetricStatProps = {
  /** Valor grande (ej. "4.7", "94%"). */
  value: string;
  /** Etiqueta corta debajo (ej. "Rating"). */
  label: string;
  /** Icono SF Symbol opcional arriba. */
  icon?: React.ReactNode;
  /** Color del valor. Por defecto, verde cancha. */
  accentColor?: string;
};

/** Métrica destacada en una celda compacta. Reemplaza `Metric`. */
export function MetricStat({ value, label, icon, accentColor }: MetricStatProps) {
  const accent = accentColor ?? colors.court;
  return (
    <View
      style={{
        backgroundColor: `${accent}14`,
        borderRadius: radii.md,
        padding: spacing.md,
        gap: spacing.xs,
        flex: 1,
        borderWidth: 1,
        borderColor: `${accent}22`
      }}
    >
      {icon ? <View style={{ marginBottom: 2 }}>{icon}</View> : null}
      <Text
        style={{
          ...typography.metric,
          color: accent,
          fontVariant: ["tabular-nums"]
        }}
      >
        {value}
      </Text>
      <Text
        style={{
          ...typography.caption,
          color: colors.textSecondary,
          fontSize: 12
        }}
      >
        {label}
      </Text>
    </View>
  );
}
