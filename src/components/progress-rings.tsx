import * as React from "react";
import { Text, View } from "react-native";
import Animated, { useAnimatedProps, useSharedValue, withDelay, withTiming } from "react-native-reanimated";
import Svg, { Circle } from "react-native-svg";
import { Icon, type IconName } from "@/components/icon";
import { useI18n } from "@/lib/i18n";
import type { Ring, RingKey } from "@/lib/gamification";
import { colors, radii, spacing, typography } from "@/theme";

/**
 * Anillos de la semana. Tres objetivos concéntricos que se rellenan al jugar,
 * disputar sets y relacionarse, y que vuelven a cero cada lunes.
 *
 * Los tres colores son rellenos de marca idénticos en claro y oscuro
 * (lima, coral, dorado): un trazo grueso teñido con un token de *tinta*
 * quedaría casi negro en modo claro y perdería la lectura de un vistazo.
 */

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

const RING_STYLE: Record<RingKey, { color: string; icon: IconName }> = {
  play: { color: colors.accentFill as string, icon: "tennis" },
  compete: { color: colors.clay as string, icon: "zap" },
  connect: { color: colors.goldFill as string, icon: "users" }
};

/** De fuera hacia dentro, como en los anillos de actividad. */
const RING_ORDER: RingKey[] = ["play", "compete", "connect"];

type ProgressRingsProps = {
  rings: Ring[];
  size?: number;
  /** Grosor del trazo; se reduce solo si el tamaño es pequeño. */
  strokeWidth?: number;
  /** Contenido central; por defecto no se dibuja nada. */
  center?: React.ReactNode;
};

export function ProgressRings({ rings, size = 168, strokeWidth, center }: ProgressRingsProps) {
  const stroke = strokeWidth ?? Math.max(9, Math.round(size * 0.085));
  const gap = Math.round(stroke * 0.42);
  const byKey = new Map(rings.map((ring) => [ring.key, ring]));

  return (
    <View style={{ height: size, width: size }}>
      <Svg width={size} height={size}>
        {RING_ORDER.map((key, index) => {
          const ring = byKey.get(key);
          if (!ring) return null;
          const radius = size / 2 - stroke / 2 - index * (stroke + gap);
          if (radius <= stroke) return null;
          return (
            <RingArc
              key={key}
              color={RING_STYLE[key].color}
              center={size / 2}
              radius={radius}
              stroke={stroke}
              progress={ring.progress}
              delay={140 * index}
            />
          );
        })}
      </Svg>
      {center ? (
        <View style={{ alignItems: "center", inset: 0, justifyContent: "center", position: "absolute" }}>
          {center}
        </View>
      ) : null}
    </View>
  );
}

function RingArc({
  color,
  center,
  radius,
  stroke,
  progress,
  delay
}: {
  color: string;
  center: number;
  radius: number;
  stroke: number;
  progress: number;
  delay: number;
}) {
  const circumference = 2 * Math.PI * radius;
  const filled = useSharedValue(0);

  React.useEffect(() => {
    filled.value = withDelay(delay, withTiming(progress, { duration: 900 }));
  }, [progress, delay, filled]);

  const animatedProps = useAnimatedProps(() => ({
    strokeDashoffset: circumference * (1 - filled.value)
  }));

  return (
    <>
      <Circle
        cx={center}
        cy={center}
        r={radius}
        stroke={color}
        strokeWidth={stroke}
        strokeOpacity={0.16}
        fill="none"
      />
      <AnimatedCircle
        cx={center}
        cy={center}
        r={radius}
        stroke={color}
        strokeWidth={stroke}
        strokeLinecap="round"
        fill="none"
        strokeDasharray={circumference}
        animatedProps={animatedProps}
        // Empezar arriba y girar en sentido horario.
        transform={`rotate(-90 ${center} ${center})`}
      />
    </>
  );
}

/** Leyenda con el valor de cada anillo — sin ella los colores no dicen nada. */
export function RingLegend({ rings, compact = false }: { rings: Ring[]; compact?: boolean }) {
  const { t } = useI18n();
  return (
    <View style={{ gap: compact ? spacing.xs : spacing.sm }}>
      {RING_ORDER.map((key) => {
        const ring = rings.find((item) => item.key === key);
        if (!ring) return null;
        const style = RING_STYLE[key];
        return (
          <View key={key} style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            {/* Relleno sólido con tinta oscura: los tres colores son claros y
                mantienen el contraste en modo claro y oscuro por igual. */}
            <View
              style={{
                alignItems: "center",
                backgroundColor: style.color,
                borderRadius: radii.sm,
                height: 26,
                justifyContent: "center",
                width: 26
              }}
            >
              <Icon name={ring.closed ? "check" : style.icon} size={13} color={colors.onAccentFill as string} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 11 }}>
                {t(`progress.rings.${key}`)}
              </Text>
              <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary, fontSize: 14 }}>
                {`${ring.value} / ${ring.goal}`}
              </Text>
            </View>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 11 }}>
              {`${Math.round(ring.progress * 100)}%`}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

/** Color sólido de cada anillo, para que el editor de objetivos vaya a juego. */
export function ringSolidColor(key: RingKey): string {
  return RING_STYLE[key].color;
}
