import * as React from "react";
import { View, type DimensionValue } from "react-native";
import { colors, spacing } from "@/theme";

type CourtLineProps = {
  /** Orientación. La horizontal simula la línea de fondo; la vertical, la red. */
  orientation?: "horizontal" | "vertical";
  /** Estilo visual. "solid" = línea de fondo, "dashed" = línea de saque. */
  variant?: "solid" | "dashed" | "net";
  /** Grosor en px. Default 1. */
  thickness?: number;
  /** Opacidad (0-1). Default 1. */
  opacity?: number;
  /** Margen vertical (solo horizontal). Default sm. */
  verticalPadding?: keyof typeof spacing;
  style?: React.ComponentProps<typeof View>["style"];
};

/**
 * Línea de cancha de tenis como elemento estructural de la UI.
 *
 * Reemplaza los separadores `border` genéricos por líneas que refuerzan la
 * identidad deportiva. Variantes:
 *  - "solid": línea de fondo o lateral. Línea continua.
 *  - "dashed": línea de saque (service line). Rayas cortas.
 *  - "net": la red. Línea con motivo de malla (puntos pequeños).
 */
export function CourtLine({
  orientation = "horizontal",
  variant = "solid",
  thickness = 1,
  opacity = 1,
  verticalPadding = "sm",
  style
}: CourtLineProps) {
  const color = colors.courtLine;
  const isHorizontal = orientation === "horizontal";

  const baseStyle = {
    backgroundColor: variant === "net" ? "transparent" : color,
    opacity
  } as const;

  // Línea "net" — malla de la red con puntos verticales pequeños.
  if (variant === "net") {
    return (
      <View
        style={{
          flexDirection: isHorizontal ? "row" : "column",
          gap: 2,
          alignItems: "center",
          justifyContent: "center",
          paddingVertical: isHorizontal ? spacing[verticalPadding] : 0,
          paddingHorizontal: isHorizontal ? 0 : spacing[verticalPadding],
          opacity
        }}
      >
        {Array.from({ length: 24 }).map((_, i) => (
          <View
            key={i}
            style={{
              backgroundColor: color,
              width: isHorizontal ? thickness : thickness * 2,
              height: isHorizontal ? thickness * 2 : thickness,
              borderRadius: thickness
            }}
          />
        ))}
      </View>
    );
  }

  // Línea dashed — service line con rayas.
  if (variant === "dashed") {
    return (
      <View
        style={{
          height: isHorizontal ? thickness : "100%" as DimensionValue,
          width: isHorizontal ? "100%" as DimensionValue : thickness,
          marginVertical: isHorizontal ? spacing[verticalPadding] : 0,
          marginHorizontal: isHorizontal ? 0 : spacing[verticalPadding],
          borderWidth: 0,
          borderStyle: "dashed",
          borderColor: color,
          borderTopWidth: isHorizontal ? thickness : 0,
          borderLeftWidth: isHorizontal ? 0 : thickness,
          opacity
        }}
      />
    );
  }

  // Línea sólida — fondo o lateral.
  return (
    <View
      style={[
        {
          ...baseStyle,
          height: isHorizontal ? thickness : "100%" as DimensionValue,
          width: isHorizontal ? "100%" as DimensionValue : thickness,
          marginVertical: isHorizontal ? spacing[verticalPadding] : 0,
          marginHorizontal: isHorizontal ? 0 : spacing[verticalPadding]
        },
        style
      ]}
    />
  );
}
