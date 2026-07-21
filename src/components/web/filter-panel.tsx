import * as React from "react";
import { Text, View, type ViewStyle } from "react-native";
import { Card } from "@/components/card";
import { Chip } from "@/components/chip";
import { colors, spacing, typography } from "@/theme";

type FilterGroup = {
  label: string;
  options: Array<{ label: string; active: boolean; onPress: () => void }>;
};

type WebFilterPanelProps = {
  groups: FilterGroup[];
  error?: string | null;
  /** Fijar el panel al hacer scroll. Solo para sidebar de desktop: en flujo
   * de una columna el sticky hace que el contenido siguiente lo pise. */
  sticky?: boolean;
  style?: ViewStyle;
};

/** Panel lateral de filtros para web — chips envueltos, no scroll horizontal. */
export function WebFilterPanel({ groups, error, sticky = false, style }: WebFilterPanelProps) {
  return (
    <Card pad="lg" gap="md" style={[sticky ? { position: "sticky" as "relative", top: 88 } : {}, style ?? {}]}>
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>Filtros</Text>
      </View>

      {error ? (
        <Text style={{ ...typography.footnote, color: colors.danger }}>{error}</Text>
      ) : null}

      {groups.map((group) => (
        <View key={group.label} style={{ gap: spacing.sm }}>
          <Text
            style={{
              ...typography.caption,
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 0.8,
              textTransform: "uppercase"
            }}
          >
            {group.label}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {group.options.map((option) => (
              <Chip
                key={option.label}
                label={option.label}
                active={option.active}
                onPress={option.onPress}
              />
            ))}
          </View>
        </View>
      ))}
    </Card>
  );
}
