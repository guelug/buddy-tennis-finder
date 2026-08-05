/**
 * Celebración de victoria: lluvia de confeti + contador de puntos en forma de
 * monedas que suben hacia el ranking. Todo con reanimated (worklets) — sin
 * dependencias nativas nuevas.
 *
 * Uso: <WinCelebration visible points={100} playerName="Pedro" onDone={...} />
 */
import { useEffect, useMemo, useState } from "react";
import { Dimensions, Pressable, Text, View } from "react-native";
import Animated, {
  Easing,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withSequence,
  withTiming
} from "react-native-reanimated";
import { useI18n } from "@/lib/i18n";
import { broadcast, colors, radii, spacing, typography } from "@/theme";

type ConfettiPiece = {
  id: number;
  /** 0-1 relativo al ancho de pantalla. */
  x: number;
  delay: number;
  duration: number;
  rotate: number;
  size: number;
  color: string;
};

const CONFETTI_COLORS = ["#C6F135", "#FFD76A", "#7BE03A", "#F5B841", "#5EE1FF", "#FF8FB1"];

function makeConfetti(count: number): ConfettiPiece[] {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    x: Math.random(),
    delay: Math.random() * 350,
    duration: 1600 + Math.random() * 1200,
    rotate: (Math.random() - 0.5) * 720,
    size: 6 + Math.random() * 6,
    color: CONFETTI_COLORS[index % CONFETTI_COLORS.length]
  }));
}

function ConfettiLayer({ active }: { active: boolean }) {
  const pieces = useMemo(() => makeConfetti(active ? 46 : 0), [active]);
  if (!active) return null;
  const { width, height } = Dimensions.get("window");
  return (
    <View pointerEvents="none" style={{ bottom: 0, left: 0, position: "absolute", right: 0, top: 0, overflow: "hidden" }}>
      {pieces.map((piece) => (
        <ConfettiPiece key={piece.id} piece={piece} width={width} height={height} />
      ))}
    </View>
  );
}

function ConfettiPiece({ piece, width, height }: { piece: ConfettiPiece; width: number; height: number }) {
  const progress = useSharedValue(0);
  const fade = useSharedValue(1);

  useEffect(() => {
    progress.value = withDelay(
      piece.delay,
      withTiming(1, { duration: piece.duration, easing: Easing.in(Easing.quad) })
    );
    fade.value = withDelay(piece.delay + piece.duration * 0.7, withTiming(0, { duration: piece.duration * 0.3 }));
  }, [piece, progress, fade]);

  const style = useAnimatedStyle(() => ({
    opacity: fade.value,
    transform: [
      { translateX: piece.x * width + Math.sin(progress.value * Math.PI * 2) * 26 },
      { translateY: -40 + progress.value * (height + 80) },
      { rotate: `${progress.value * piece.rotate}deg` }
    ]
  }));

  return (
    <Animated.View
      style={[
        style,
        {
          backgroundColor: piece.color,
          borderRadius: 2,
          height: piece.size * 0.6,
          position: "absolute",
          top: 0,
          width: piece.size
        }
      ]}
    />
  );
}

/** Moneda que sube con el valor de puntos — la guinda de la celebración. */
function CoinPoints({ points, visible }: { points: number; visible: boolean }) {
  const rise = useSharedValue(0);
  const scale = useSharedValue(0.4);
  const [displayed, setDisplayed] = useState(0);

  useEffect(() => {
    if (!visible) return;
    rise.value = withTiming(1, { duration: 900, easing: Easing.out(Easing.cubic) });
    scale.value = withSequence(
      withTiming(1.18, { duration: 320, easing: Easing.out(Easing.back(2)) }),
      withTiming(1, { duration: 180 })
    );
    // Cuenta de puntos animada (el contador corre en JS, barato para 100).
    const start = Date.now();
    const tick = () => {
      const elapsed = Date.now() - start;
      const ratio = Math.min(1, elapsed / 800);
      setDisplayed(Math.round(points * ratio));
      if (ratio < 1) setTimeout(tick, 40);
    };
    tick();
  }, [visible, points, rise, scale]);

  const style = useAnimatedStyle(() => ({
    opacity: rise.value,
    transform: [{ scale: scale.value }, { translateY: (1 - rise.value) * 30 }]
  }));

  return (
    <Animated.View style={[style, { alignItems: "center", gap: spacing.xs }]}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <View style={{ alignItems: "center", backgroundColor: "#FFD76A", borderRadius: 999, height: 44, justifyContent: "center", width: 44 }}>
          <Text style={{ color: "#7A5A00", fontSize: 22 }}>🏆</Text>
        </View>
        <Text style={{ ...broadcast.stat, color: "#FFD76A", fontSize: 40 }}>+{displayed}</Text>
      </View>
    </Animated.View>
  );
}

export function WinCelebration({
  visible,
  points,
  playerName,
  onDone
}: {
  visible: boolean;
  points: number;
  playerName: string;
  onDone?: () => void;
}) {
  const { t } = useI18n();
  const fade = useSharedValue(0);

  useEffect(() => {
    if (visible) {
      fade.value = withTiming(1, { duration: 260 });
      // La celebración dura 3,2 s y se cierra sola (o antes, con un toque).
      const timer = setTimeout(() => {
        fade.value = withTiming(0, { duration: 260 });
        setTimeout(() => onDone?.(), 280);
      }, 3200);
      return () => clearTimeout(timer);
    }
    return undefined;
  }, [visible, fade, onDone]);

  if (!visible) return null;

  return (
    <Animated.View style={{ opacity: fade, bottom: 0, left: 0, position: "absolute", right: 0, top: 0, zIndex: 1200 }}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={t("matches.win.dismiss")}
        onPress={() => {
          fade.value = withTiming(0, { duration: 200 });
          setTimeout(() => onDone?.(), 220);
        }}
        style={{ alignItems: "center", backgroundColor: "rgba(3,8,5,.78)", flex: 1, justifyContent: "center" }}
      >
        <ConfettiLayer active={visible} />
        <View style={{ alignItems: "center", gap: spacing.md, paddingHorizontal: spacing.xl }}>
          <Text style={{ ...broadcast.jersey, color: "#FFD76A", fontSize: 13, letterSpacing: 2 }}>
            {t("matches.win.eyebrow")}
          </Text>
          <Text style={{ ...broadcast.hero, color: "#fff", fontSize: 30, lineHeight: 34, textAlign: "center" }}>
            {t("matches.win.title").replace("{name}", playerName)}
          </Text>
          <CoinPoints points={points} visible={visible} />
          <Text style={{ ...typography.footnote, color: "rgba(255,255,255,.72)", textAlign: "center" }}>
            {t("matches.win.subtitle")}
          </Text>
          <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, marginTop: spacing.sm, paddingHorizontal: spacing.lg, paddingVertical: spacing.sm }}>
            <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t("matches.win.dismiss")}</Text>
          </View>
        </View>
      </Pressable>
    </Animated.View>
  );
}
