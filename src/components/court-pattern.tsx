import * as React from "react";
import { Platform, View } from "react-native";
import Svg, { Line, Rect } from "react-native-svg";
import { colors } from "@/theme";

type CourtPatternProps = {
  /** Opacidad del patrón. Default 0.06 (muy sutil). */
  opacity?: number;
  /** Color de las líneas. Default courtLine. */
  lineColor?: string;
  /** Mostrar el service box central. Default true. */
  showServiceBoxes?: boolean;
  style?: React.ComponentProps<typeof View>["style"];
};

/**
 * Patrón de cancha de tenis dibujado como fondo decorativo.
 * Muy sutil por defecto (opacity 0.06) — refuerza la identidad sin distraer.
 *
 * Se renderiza absoluto dentro de un contenedor posicionado. Úsalo como capa
 * de fondo en pantallas hero o headers de marca.
 */
export function CourtPattern({
  opacity = 0.06,
  lineColor,
  showServiceBoxes = true,
  style
}: CourtPatternProps) {
  const stroke = lineColor ?? (Platform.OS === "ios" ? "#0A4D2C" : "#0A4D2C");

  return (
    <View pointerEvents="none" style={[{ position: "absolute", inset: 0, opacity }, style]}>
      <Svg width="100%" height="100%" viewBox="0 0 360 200" preserveAspectRatio="xMidYMid slice">
        {/* Marco exterior de la cancha */}
        <Rect x="20" y="20" width="320" height="160" fill="none" stroke={stroke} strokeWidth="1.5" />
        {/* Línea central (red) */}
        <Line x1="20" y1="100" x2="340" y2="100" stroke={stroke} strokeWidth="1.5" />
        {/* Línea central vertical (en el fondo) */}
        <Line x1="180" y1="20" x2="180" y2="180" stroke={stroke} strokeWidth="1" opacity="0.6" />
        {showServiceBoxes ? (
          <>
            {/* Service lines */}
            <Line x1="90" y1="20" x2="270" y2="20" stroke={stroke} strokeWidth="1" opacity="0.5" />
            <Line x1="90" y1="180" x2="270" y2="180" stroke={stroke} strokeWidth="1" opacity="0.5" />
            <Line x1="90" y1="20" x2="90" y2="180" stroke={stroke} strokeWidth="1" opacity="0.5" />
            <Line x1="270" y1="20" x2="270" y2="180" stroke={stroke} strokeWidth="1" opacity="0.5" />
          </>
        ) : null}
      </Svg>
    </View>
  );
}

// silence unused en algunos bundlers
void colors;
