import * as React from "react";
import { View, type DimensionValue } from "react-native";
import Svg, { Line, Rect } from "react-native-svg";

type Props = {
  width?: DimensionValue;
  color?: string;
};

/**
 * Línea decorativa tipo cancha de tenis: línea central con red.
 * Se usa como separador sutil entre secciones para reforzar identidad.
 */
export function CourtDivider({ width = "100%", color = "#0B5E3A" }: Props) {
  return (
    <View style={{ alignItems: "center", opacity: 0.25, paddingVertical: 4 }}>
      <Svg width={120} height={12} viewBox="0 0 120 12">
        <Rect x="58" y="0" width="4" height="12" rx="1" fill={color} />
        <Line x1="0" y1="6" x2="50" y2="6" stroke={color} strokeWidth="1.4" strokeLinecap="round" />
        <Line x1="70" y1="6" x2="120" y2="6" stroke={color} strokeWidth="1.4" strokeLinecap="round" />
      </Svg>
      <View style={{ width, height: 1, backgroundColor: "transparent" }} />
    </View>
  );
}
