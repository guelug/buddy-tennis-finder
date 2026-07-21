import * as React from "react";
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSequence,
  withTiming,
  withSpring,
  withDelay,
  Easing,
  interpolate,
  runOnJS
} from "react-native-reanimated";
import { motion } from "@/theme";

/**
 * ANIMACIÓN SIGNATURE de MatchPoint Tennis: la pelota rebotando.
 *
 * Física real de una pelota de tenis cayendo en cancha dura:
 *   1. Cae desde arriba (translateY -24 → 0) con aceleración de gravedad.
 *   2. Al impacto, comprime verticalmente (scaleY 1 → 0.78, scaleX 1 → 1.12).
 *   3. Recupera con rebote al ~53% (ITF coeficiente de restitución).
 *   4. Asentamiento final con spring.
 *
 * Esta es NUESTRA animación. Se usa en cards, listas y entradas de pantalla
 * para dar coherencia total y un "sentir pelota" reconocible.
 *
 * NO es un FadeIn.delay genérico. Es una decisión de diseño.
 */

type BallBounceProps = {
  children: React.ReactNode;
  /** Retraso en ms (para stagger de listas). Default 0. */
  delay?: number;
  /** Distancia de caída inicial en px. Default 24. */
  dropDistance?: number;
  /** Compresión al impacto (0-1, menor = más squash). Default 0.78. */
  squash?: number;
  /** Reproducir al montar. Default true. */
  play?: boolean;
  style?: React.ComponentProps<typeof Animated.View>["style"];
};

export function BallBounce({
  children,
  delay = 0,
  dropDistance = 24,
  squash = 0.78,
  play = true,
  style
}: BallBounceProps) {
  const translateY = useSharedValue(play ? -dropDistance : 0);
  const scaleX = useSharedValue(1);
  const scaleY = useSharedValue(1);

  React.useEffect(() => {
    if (!play) return;

    // Fase 1: caída con gravedad (ease-in acelerando).
    // Fase 2: impacto — squash & stretch simultáneo.
    // Fase 3: rebote al 53% de altura con la misma física.
    // Fase 4: asentamiento con spring natural.
    const gravityEase = Easing.bezier(0.55, 0, 0.85, 0.3); // ease-in cuadrático
    const impactEase = Easing.bezier(0.2, 0.8, 0.2, 1); // ease-out

    translateY.value = withDelay(
      delay,
      withSequence(
        // Caída
        withTiming(0, { duration: 280, easing: gravityEase }),
        // Rebote al 53% (sube)
        withTiming(-dropDistance * 0.53, { duration: 220, easing: impactEase }),
        // Cae de nuevo
        withTiming(0, { duration: 200, easing: gravityEase }),
        // Asentamiento spring
        withSpring(0, { damping: 18, stiffness: 280, mass: 0.8 })
      )
    );

    scaleX.value = withDelay(
      delay,
      withSequence(
        withTiming(1, { duration: 280 }), // durante caída, normal
        // Impacto: ensancha
        withTiming(1 / squash, { duration: 80, easing: Easing.out(Easing.quad) }),
        withTiming(1, { duration: 140, easing: Easing.out(Easing.quad) }),
        // Segundo impacto menor
        withTiming(1 + (1 / squash - 1) * 0.4, { duration: 60 }),
        withSpring(1, { damping: 16, stiffness: 320 })
      )
    );

    scaleY.value = withDelay(
      delay,
      withSequence(
        withTiming(1, { duration: 280 }),
        // Impacto: aplasta
        withTiming(squash, { duration: 80, easing: Easing.out(Easing.quad) }),
        withTiming(1, { duration: 140, easing: Easing.out(Easing.quad) }),
        // Segundo impacto menor
        withTiming(squash + (1 - squash) * 0.5, { duration: 60 }),
        withSpring(1, { damping: 16, stiffness: 320 })
      )
    );
  }, [play, delay, dropDistance, squash, translateY, scaleX, scaleY]);

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [
        { translateY: translateY.value },
        { scaleX: scaleX.value },
        { scaleY: scaleY.value }
      ]
    };
  }, []);

  return <Animated.View style={[animatedStyle, style]}>{children}</Animated.View>;
}

/**
 * Versión "tile" para elementos que rebotan como pelota al aparecer en grid.
 * Variante más contenida (sin segundo rebote) para listas largas.
 */
export function BallDrop({
  children,
  delay = 0,
  style
}: {
  children: React.ReactNode;
  delay?: number;
  style?: React.ComponentProps<typeof Animated.View>["style"];
}) {
  const translateY = useSharedValue(-16);
  const scale = useSharedValue(0.92);

  React.useEffect(() => {
    const ease = Easing.bezier(0.55, 0, 0.85, 0.3);
    translateY.value = withDelay(
      delay,
      withSequence(
        withTiming(0, { duration: 240, easing: ease }),
        withSpring(0, { damping: 18, stiffness: 280 })
      )
    );
    scale.value = withDelay(
      delay,
      withSequence(
        withTiming(0.96, { duration: 240, easing: ease }),
        withSpring(1, { damping: 14, stiffness: 320 })
      )
    );
  }, [delay, translateY, scale]);

  const animatedStyle = useAnimatedStyle(
    () => ({
      transform: [{ translateY: translateY.value }, { scale: scale.value }]
    }),
    []
  );

  return <Animated.View style={[animatedStyle, style]}>{children}</Animated.View>;
}

/**
 * Hook para reproducir un "serve" programático: anima un shared value de 0→1
 * con física de saque. Útil para el momento de "proponer partido".
 */
export function useServeTrigger() {
  const serve = useSharedValue(0);

  const fire = React.useCallback(() => {
    serve.value = withSequence(
      withTiming(0, { duration: 0 }),
      withSpring(1, motion.serve)
    );
  }, [serve]);

  return { serve, fire };
}

/**
 * Estilo animado derivado del trigger de serve. Úsalo en la pelota del "Propose".
 */
export function useServeStyle(serve: ReturnType<typeof useServeTrigger>["serve"]) {
  return useAnimatedStyle(
    () => ({
      transform: [
        { translateY: interpolate(serve.value, [0, 0.5, 1], [0, -40, -120]) },
        { scale: interpolate(serve.value, [0, 0.3, 1], [1, 1.2, 0.4]) },
        { rotate: `${interpolate(serve.value, [0, 1], [0, 360])}deg` }
      ],
      opacity: interpolate(serve.value, [0, 0.7, 1], [1, 1, 0])
    }),
    [serve]
  );
}

// Silenciar lint de import no usado en algunos entornos.
void runOnJS;
