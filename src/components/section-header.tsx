import * as React from "react";
import { Text, View } from "react-native";
import { colors, spacing, typography } from "@/theme";

type SectionHeaderProps = {
  /** Título principal (large title estilo Apple). */
  title: string;
  /** Subtítulo opcional. */
  subtitle?: string;
  /** Emoji o icono a la izquierda del título. */
  eyebrow?: string;
  /** Acción opcional a la derecha (ej. "Ver todo"). */
  rightAction?: React.ReactNode;
};

/** Cabecera de sección estilo Apple: large title + subtítulo + acción opcional. */
export function SectionHeader({ title, subtitle, eyebrow, rightAction }: SectionHeaderProps) {
  return (
    <View style={{ gap: spacing.xs, paddingHorizontal: spacing.base }}>
      {eyebrow ? (
        <Text
          style={{
            ...typography.caption,
            color: colors.court,
            fontSize: 12,
            textTransform: "uppercase",
            letterSpacing: 1.4,
            fontWeight: "800"
          }}
        >
          {eyebrow}
        </Text>
      ) : null}
      <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "flex-end" }}>
        <Text style={{ ...typography.largeTitle, color: colors.textPrimary, flex: 1 }}>
          {title}
        </Text>
        {rightAction}
      </View>
      {subtitle ? (
        <Text style={{ ...typography.body, color: colors.textSecondary }}>
          {subtitle}
        </Text>
      ) : null}
    </View>
  );
}
