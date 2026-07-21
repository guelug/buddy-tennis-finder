import * as React from "react";
import { ScrollView, Text, View } from "react-native";
import { Chip } from "@/components/chip";
import { Icon } from "@/components/icon";
import { colors, spacing, typography } from "@/theme";

type FilterOption = {
  label: string;
  active: boolean;
  onPress: () => void;
};

type FilterStripProps = {
  title?: string;
  options: FilterOption[];
  /** Acción opcional a la derecha del título (ej. ubicación). */
  action?: React.ReactNode;
};

/** Fila horizontal de chips deslizables — patrón nativo para filtros rápidos. */
export function FilterStrip({ title, options, action }: FilterStripProps) {
  return (
    <View style={{ gap: spacing.sm }}>
      {title || action ? (
        <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
          {title ? (
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              <Icon name="sliders" size={14} color={colors.textSecondary as string} />
              <Text style={{ ...typography.caption, color: colors.textSecondary, fontSize: 12 }}>
                {title}
              </Text>
            </View>
          ) : (
            <View />
          )}
          {action}
        </View>
      ) : null}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ gap: spacing.sm, paddingRight: spacing.base }}
      >
        {options.map((option) => (
          <Chip
            key={option.label}
            label={option.label}
            active={option.active}
            onPress={option.onPress}
          />
        ))}
      </ScrollView>
    </View>
  );
}