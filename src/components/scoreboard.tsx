import * as React from "react";
import { Text, View } from "react-native";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  withDelay,
  withSequence,
  Easing,
  interpolate,
  withSpring
} from "react-native-reanimated";
import { broadcast, colors, shadows, spacing, radii } from "@/theme";

type ScoreboardProps = {
  /** Valor numérico a mostrar. */
  value: number | string;
  /** Etiqueta corta debajo (ej. "match"). */
  label?: string;
  /** Variante de tamaño. */
  size?: "md" | "lg";
  /** Variante de color. Default court (verde cancha). */
  accent?: "court" | "spotlight";
  /** Retraso para stagger de entrada. */
  delay?: number;
};

/**
 * Scoreboard estilo broadcast — el componente más identitario de la app.
 *
 * Características:
 *  - Dígitos en Saira Condensed Black (tipografía deportiva).
 *  - Fondo verde cancha profundo con esquinas suaves (estilo LED screen).
 *  - Animación de entrada: dígito "cae y rebota" como pelota (BallBounce).
 *  - El label aparece con fade-in retrasado.
 *
 * Este componente hace que un "92" se sienta como marcador en vivo,
 * no como un número de contacto.
 */
export function Scoreboard({
  value,
  label,
  size = "md",
  accent = "court",
  delay = 0
}: ScoreboardProps) {
  const bg = accent === "spotlight" ? colors.spotlight : colors.courtDeep;
  const fg = accent === "spotlight" ? colors.textOnBall : colors.textOnCourt;

  const fontSize = size === "lg" ? 56 : 40;
  const padding = size === "lg" ? spacing.md : spacing.sm + 2;
  const minWidth = size === "lg" ? 88 : 68;

  // Animación de entrada tipo "pelota rebotando" para el dígito.
  const translateY = useSharedValue(-20);
  const scaleY = useSharedValue(1);

  React.useEffect(() => {
    const ease = Easing.bezier(0.55, 0, 0.85, 0.3);
    translateY.value = withDelay(
      delay,
      withSequence(
        withTiming(0, { duration: 260, easing: ease }),
        withSpring(0, { damping: 14, stiffness: 280 })
      )
    );
    scaleY.value = withDelay(
      delay,
      withSequence(
        withTiming(1, { duration: 260 }),
        // squash al impacto
        withTiming(0.82, { duration: 70, easing: Easing.out(Easing.quad) }),
        withTiming(1, { duration: 130, easing: Easing.out(Easing.quad) }),
        withSpring(1, { damping: 16, stiffness: 320 })
      )
    );
  }, [delay, translateY, scaleY]);

  const digitStyle = useAnimatedStyle(
    () => ({
      transform: [
        { translateY: translateY.value },
        { scaleY: scaleY.value }
      ]
    }),
    []
  );

  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: bg,
        borderRadius: radii.md,
        boxShadow: accent === "spotlight" ? shadows.spotlightGlow : shadows.courtGlow,
        justifyContent: "center",
        minWidth,
        paddingHorizontal: padding,
        paddingVertical: padding - 2
      }}
    >
      <Animated.View style={digitStyle} key={String(value)}>
        <Text
          style={{
            ...broadcast.scoreboard,
            color: fg,
            fontSize,
            fontVariant: ["tabular-nums"]
          }}
        >
          {value}
        </Text>
      </Animated.View>
      {label ? (
        <Text
          style={{
            ...broadcast.jersey,
            color: accent === "spotlight" ? "rgba(10,24,16,0.7)" : "rgba(255,255,255,0.78)",
            fontSize: 9,
            letterSpacing: 1.2,
            textTransform: "uppercase"
          }}
        >
          {label}
        </Text>
      ) : null}
    </View>
  );
}

// silence unused
void interpolate;
