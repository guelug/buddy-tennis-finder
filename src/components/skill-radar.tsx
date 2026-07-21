import * as React from "react";
import { Text, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withSpring,
  withTiming
} from "react-native-reanimated";
import Svg, { Circle, Line, Polygon } from "react-native-svg";
import { colors, spacing, typography, useThemeMode } from "@/theme";
import { PlayerSkills } from "@/types";

/**
 * Pentágono de habilidades del perfil (concepto "Night Session").
 *
 * Serie única: polígono lima neón con relleno translúcido sobre grid de
 * hairlines recesivos. Los labels usan tokens de texto (no el color de serie).
 * El polígono de datos entra con spring de escala desde el centro, estilo
 * radar que "se enciende".
 */

const AXES: Array<{ key: keyof PlayerSkills; label: string }> = [
  { key: "consistency", label: "Consistencia" },
  { key: "forehand", label: "Derecha" },
  { key: "backhand", label: "Revés" },
  { key: "serve", label: "Servicio" },
  { key: "volley", label: "Volea" }
];

/** Derivación estable cuando el jugador aún no tiene skills guardadas. */
export function skillsFromRating(rating: number): PlayerSkills {
  const base = Math.min(9.5, Math.max(4, rating * 1.75));
  return {
    consistency: round1(base),
    volley: round1(base - 0.6),
    forehand: round1(base - 0.2),
    backhand: round1(base - 0.5),
    serve: round1(Math.min(10, base + 0.3))
  };
}

export function averageReviewSkills(
  ratings: Array<PlayerSkills | undefined>,
  fallback: PlayerSkills
): { skills: PlayerSkills; count: number } {
  const valid = ratings.filter((item): item is PlayerSkills => !!item);
  if (valid.length === 0) return { skills: fallback, count: 0 };
  const keys: Array<keyof PlayerSkills> = ["consistency", "forehand", "backhand", "serve", "volley"];
  const skills = {} as PlayerSkills;
  for (const key of keys) {
    skills[key] = round1(valid.reduce((sum, item) => sum + item[key], 0) / valid.length);
  }
  return { skills, count: valid.length };
}

function round1(value: number) {
  return Math.round(value * 10) / 10;
}

function vertex(center: number, radius: number, index: number, scale = 1) {
  // -90° arriba; 5 ejes cada 72°.
  const angle = (-90 + index * 72) * (Math.PI / 180);
  return {
    x: center + radius * scale * Math.cos(angle),
    y: center + radius * scale * Math.sin(angle)
  };
}

function polygonPoints(center: number, radius: number, scales: number[]) {
  return scales
    .map((scale, index) => {
      const { x, y } = vertex(center, radius, index, scale);
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");
}

export function SkillRadar({
  skills,
  size = 250,
  delay = 200,
  provisional = false
}: {
  skills: PlayerSkills;
  size?: number;
  delay?: number;
  provisional?: boolean;
}) {
  const { isLight } = useThemeMode();
  // Margen para labels alrededor del pentágono.
  const labelGutter = 34;
  const plot = size - labelGutter * 2;
  const center = plot / 2;
  const radius = plot / 2 - 6;

  const values = AXES.map(({ key }) => Math.min(10, Math.max(0, skills[key])) / 10);

  // Entrada: el polígono "se enciende" desde el centro.
  const scale = useSharedValue(0.35);
  const opacity = useSharedValue(0);

  React.useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration: 220 }));
    scale.value = withDelay(delay, withSpring(1, { damping: 13, stiffness: 160 }));
  }, [delay, opacity, scale]);

  const dataStyle = useAnimatedStyle(
    () => ({ opacity: opacity.value, transform: [{ scale: scale.value }] }),
    []
  );

  const seriesColor = provisional ? colors.danger : colors.neon;
  const seriesFill = provisional
    ? (isLight ? "rgba(196,60,50,0.12)" : "rgba(255,107,90,0.18)")
    : (isLight ? "rgba(82,122,0,0.14)" : "rgba(198,241,53,0.20)");
  const gridColor = colors.courtLine as string;
  const spokeColor = colors.border as string;

  return (
    <View style={{ alignSelf: "center", height: size, width: size }}>
      <View style={{ left: labelGutter, position: "absolute", top: labelGutter }}>
        {/* Grid estático: 3 pentágonos + radios */}
        <Svg width={plot} height={plot}>
          {[1, 0.66, 0.33].map((level) => (
            <Polygon
              key={level}
              points={polygonPoints(center, radius, values.map(() => level))}
              fill="none"
              stroke={gridColor}
              strokeWidth={1}
            />
          ))}
          {values.map((_, index) => {
            const outer = vertex(center, radius, index);
            return (
              <Line
                key={index}
                x1={center}
                y1={center}
                x2={outer.x}
                y2={outer.y}
                stroke={spokeColor}
                strokeWidth={1}
              />
            );
          })}
        </Svg>

        {/* Polígono de datos animado (SVG aparte para escalar desde el centro) */}
        <Animated.View style={[dataStyle, { left: 0, position: "absolute", top: 0 }]}>
          <Svg width={plot} height={plot}>
            <Polygon
              points={polygonPoints(center, radius, values)}
              fill={seriesFill}
              stroke={seriesColor}
              strokeWidth={2}
              strokeLinejoin="round"
            />
            {values.map((value, index) => {
              const point = vertex(center, radius, index, value);
              return (
                <Circle
                  key={index}
                  cx={point.x}
                  cy={point.y}
                  r={4}
                  fill={seriesColor}
                  stroke="rgba(8,19,10,0.9)"
                  strokeWidth={2}
                />
              );
            })}
          </Svg>
        </Animated.View>
      </View>

      {/* Labels por eje: nombre en secundario, valor en primario */}
      {AXES.map(({ key, label }, index) => {
        const point = vertex(center, radius, index, 1.0);
        const x = labelGutter + point.x;
        const y = labelGutter + point.y;
        // Alineación según el lado del pentágono.
        const isTop = index === 0;
        const isRight = index === 1 || index === 2;
        const style =
          isTop
            ? { left: x - 60, top: y - 34, width: 120, alignItems: "center" as const }
            : isRight
              ? { left: x + 6, top: y - 9, width: labelGutter + 56, alignItems: "flex-start" as const }
              : { left: x - labelGutter - 62, top: y - 9, width: labelGutter + 56, alignItems: "flex-end" as const };

        return (
          <View key={key} pointerEvents="none" style={[{ position: "absolute", gap: 1 }, style]}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 11 }}>{label}</Text>
              <Text style={{ ...typography.caption, color: colors.textPrimary, fontSize: 12, fontWeight: "800" }}>
                {skills[key].toFixed(1)}
              </Text>
            </View>
          </View>
        );
      })}
    </View>
  );
}
