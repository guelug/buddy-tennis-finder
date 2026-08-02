import * as React from "react";
import { Animated, Easing, Platform, Text, View } from "react-native";
import Svg, {
  Defs,
  Ellipse,
  Line,
  LinearGradient,
  Path,
  Polygon,
  RadialGradient,
  Rect,
  Stop
} from "react-native-svg";
import { broadcast, colors, radii, shadows, spacing, useThemeMode } from "@/theme";

/**
 * Peloteo en pista — animación "match en vivo" del concepto Night Session.
 *
 * Una pista de tenis en perspectiva (cámara de transmisión) con la pelota
 * peloteando cruzado de un fondo al otro: arco parabólico, bote con sombra que
 * la sigue, escala por profundidad (más grande cerca, pequeña lejos), giro y un
 * destello de neón en cada bote.
 *
 * Nota técnica: usamos el `Animated` de react-native (no Reanimated) porque los
 * loops continuos de shared values de Reanimated no refrescan el DOM en el build
 * web actual. Precomputamos la trayectoria y la interpolamos con una sola
 * Animated.Value en bucle — fluido y 1:1 en web y nativo.
 */

const NEON = "#C6F135";
const NEON_BRIGHT = "#E4FF6A";

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

type RallyGeo = {
  cx: number;
  farY: number;
  nearY: number;
  farHalf: number;
  nearHalf: number;
  A1: number;
  A2: number;
  bouncePoint: number;
  ballDia: number;
};

/** Física del peloteo en función del progreso 0..1. */
function sampleRally(prog: number, g: RallyGeo) {
  const isFirst = prog < 0.5;
  // d: 0 (fondo lejano) -> 1 (fondo cercano) -> 0
  const d = isFirst ? prog * 2 : (1 - prog) * 2;
  const local = isFirst ? d : 1 - d;
  const f = isFirst ? lerp(-0.58, 0.58, local) : lerp(0.58, -0.58, local);

  let h: number;
  if (local < g.bouncePoint) {
    h = Math.sin((local / g.bouncePoint) * Math.PI) * g.A1;
  } else {
    h = Math.sin(((local - g.bouncePoint) / (1 - g.bouncePoint)) * Math.PI) * g.A2;
  }
  const hopNorm = h / g.A1;

  const groundY = lerp(g.farY, g.nearY, d);
  const halfW = lerp(g.farHalf, g.nearHalf, d);
  const groundX = g.cx + f * halfW * 0.92;
  const scale = lerp(0.5, 1.18, d);

  return { groundX, groundY, h, hopNorm, scale };
}

type CourtRallyProps = {
  size?: number;
  width?: number;
  height?: number;
  label?: string;
  duration?: number;
};

export function CourtRally({ size = 150, width, height, label, duration = 3400 }: CourtRallyProps) {
  const { isLight } = useThemeMode();
  const W = width ?? size;
  const H = height ?? size;

  // En modo claro la pista va sobre cards blancas: necesita relleno casi
  // sólido y líneas blancas (como una pista real); en oscuro va en neón
  // translúcido sobre el fondo nocturno.
  const line = isLight ? "#FFFFFF" : NEON;
  const lineOp = (dark: number) => (isLight ? Math.min(1, dark + 0.45) : dark + 0.18);

  // Geometría de la pista en perspectiva (fracciones del box).
  // Usamos W y H reales para que la pista llene el rectángulo disponible.
  const cx = W * 0.5;
  const farY = H * 0.22;
  const nearY = H * 0.86;
  const farHalf = W * 0.16;
  const nearHalf = W * 0.46;

  const yAt = (dd: number) => lerp(farY, nearY, dd);
  const halfAt = (dd: number) => lerp(farHalf, nearHalf, dd);

  const dServiceFar = 0.32;
  const dNet = 0.5;
  const dServiceNear = 0.72;

  const ballDia = size * 0.14;
  const A1 = H * 0.3;
  const A2 = A1 * 0.5;
  const bouncePoint = 0.56;
  const geo: RallyGeo = { cx, farY, nearY, farHalf, nearHalf, A1, A2, bouncePoint, ballDia };

  // Bases de sombra y destello (se escalan por interpolación).
  const shadowW0 = ballDia * 1.5;
  const shadowH0 = ballDia * 0.44;
  const flash0 = ballDia * 4;

  // -------------------------------------------------------------------------
  // Precómputo de la trayectoria (N muestras) → interpolación fluida.
  // -------------------------------------------------------------------------
  const N = 72;
  const trailLead = 0.05;
  const samples = React.useMemo(() => {
    const input: number[] = [];
    const ballTX: number[] = [];
    const ballTY: number[] = [];
    const ballScale: number[] = [];
    const trailTX: number[] = [];
    const trailTY: number[] = [];
    const trailScale: number[] = [];
    const shTX: number[] = [];
    const shTY: number[] = [];
    const shScaleX: number[] = [];
    const shScaleY: number[] = [];
    const shOpacity: number[] = [];
    const flTX: number[] = [];
    const flTY: number[] = [];
    const flScale: number[] = [];
    const flOpacity: number[] = [];

    for (let i = 0; i <= N; i++) {
      const prog = i / N;
      const r = sampleRally(prog, geo);
      input.push(prog);

      ballTX.push(r.groundX - ballDia / 2);
      ballTY.push(r.groundY - r.h - ballDia / 2);
      ballScale.push(r.scale);

      let tprog = prog - trailLead;
      if (tprog < 0) tprog += 1;
      const rt = sampleRally(tprog, geo);
      trailTX.push(rt.groundX - ballDia / 2);
      trailTY.push(rt.groundY - rt.h - ballDia / 2);
      trailScale.push(rt.scale * 0.86);

      shTX.push(r.groundX - shadowW0 / 2);
      shTY.push(r.groundY - shadowH0 / 2);
      shScaleX.push(r.scale * lerp(1.15, 0.55, r.hopNorm));
      shScaleY.push(r.scale);
      shOpacity.push(lerp(0.42, 0.06, r.hopNorm));

      const flSize = ballDia * (1.6 + (1 - r.hopNorm) * 2.4) * r.scale;
      flTX.push(r.groundX - flash0 / 2);
      flTY.push(r.groundY - (flash0 * 0.42) / 2);
      flScale.push(flSize / flash0);
      flOpacity.push((1 - Math.min(1, r.hopNorm / 0.14)) * 0.5);
    }

    return {
      input,
      ballTX,
      ballTY,
      ballScale,
      trailTX,
      trailTY,
      trailScale,
      shTX,
      shTY,
      shScaleX,
      shScaleY,
      shOpacity,
      flTX,
      flTY,
      flScale,
      flOpacity
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [size]);

  const t = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(t, {
        toValue: 1,
        duration,
        easing: Easing.linear,
        // Solo animamos transform + opacity → el driver nativo es válido en
        // iOS/Android (hilo de UI, sin jank). En web no existe → rAF.
        useNativeDriver: Platform.OS !== "web"
      })
    );
    loop.start();
    return () => loop.stop();
  }, [t, duration]);

  const interp = (out: number[]) => t.interpolate({ inputRange: samples.input, outputRange: out });
  const rotate = t.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "720deg"] });

  // Líneas estáticas de la pista.
  const courtPts = `${cx - nearHalf},${nearY} ${cx + nearHalf},${nearY} ${cx + farHalf},${farY} ${cx - farHalf},${farY}`;
  const serviceFarL = { x: cx - halfAt(dServiceFar), y: yAt(dServiceFar) };
  const serviceFarR = { x: cx + halfAt(dServiceFar), y: yAt(dServiceFar) };
  const serviceNearL = { x: cx - halfAt(dServiceNear), y: yAt(dServiceNear) };
  const serviceNearR = { x: cx + halfAt(dServiceNear), y: yAt(dServiceNear) };
  const netHalf = halfAt(dNet) * 1.08;
  const netY = yAt(dNet);

  return (
    <View style={{ alignItems: "center", height: H, justifyContent: "center", width: W }}>
      {/* Pista */}
      <Svg width={W} height={H} style={{ position: "absolute" }}>
        <Defs>
          <LinearGradient id="courtFill" x1="0" y1="0" x2="0" y2="1">
            {[
              <Stop key="0" offset="0" stopColor={isLight ? "#14633A" : "#0C3D24"} stopOpacity={isLight ? 0.97 : 0.28} />,
              <Stop key="1" offset="0.5" stopColor={isLight ? "#0F4A2C" : "#0F4A2C"} stopOpacity={isLight ? 0.98 : 0.55} />,
              <Stop key="2" offset="1" stopColor={isLight ? "#0A2E1B" : "#0A2E1B"} stopOpacity={isLight ? 1 : 0.82} />
            ]}
          </LinearGradient>
          <RadialGradient id="courtGlow" cx="50%" cy="42%" r="60%">
            <Stop offset="0" stopColor={NEON} stopOpacity={isLight ? 0 : 0.16} />
            <Stop offset="1" stopColor={NEON} stopOpacity="0" />
          </RadialGradient>
        </Defs>

        <Rect x="0" y="0" width={W} height={H} fill="url(#courtGlow)" />
        <Polygon points={courtPts} fill="url(#courtFill)" stroke={line} strokeOpacity={lineOp(0.55)} strokeWidth={1.5} />

        <Line {...toLine(serviceFarL, serviceFarR)} stroke={line} strokeOpacity={lineOp(0.28)} strokeWidth={1} />
        <Line {...toLine(serviceNearL, serviceNearR)} stroke={line} strokeOpacity={lineOp(0.34)} strokeWidth={1} />
        <Line
          x1={cx}
          y1={yAt(dServiceFar)}
          x2={cx}
          y2={yAt(dServiceNear)}
          stroke={line}
          strokeOpacity={lineOp(0.24)}
          strokeWidth={1}
        />
        <Line x1={cx} y1={farY} x2={cx} y2={farY + H * 0.03} stroke={line} strokeOpacity={lineOp(0.3)} strokeWidth={1} />
        <Line x1={cx} y1={nearY} x2={cx} y2={nearY - H * 0.03} stroke={line} strokeOpacity={lineOp(0.36)} strokeWidth={1} />

        <Line x1={cx - netHalf} y1={netY} x2={cx + netHalf} y2={netY} stroke="#EAF3E4" strokeOpacity={0.5} strokeWidth={1.5} />
        <NetMesh cx={cx} netHalf={netHalf} netY={netY} />
        <Line x1={cx - netHalf} y1={netY} x2={cx - netHalf} y2={netY - H * 0.05} stroke="#EAF3E4" strokeOpacity={0.4} strokeWidth={1.5} />
        <Line x1={cx + netHalf} y1={netY} x2={cx + netHalf} y2={netY - H * 0.05} stroke="#EAF3E4" strokeOpacity={0.4} strokeWidth={1.5} />
      </Svg>

      {/* Destello de bote */}
      <Animated.View
        pointerEvents="none"
        style={{
          height: flash0 * 0.42,
          left: 0,
          opacity: interp(samples.flOpacity),
          position: "absolute",
          top: 0,
          width: flash0,
          transform: [
            { translateX: interp(samples.flTX) },
            { translateY: interp(samples.flTY) },
            { scale: interp(samples.flScale) }
          ]
        }}
      >
        <Svg width="100%" height="100%">
          <Ellipse cx="50%" cy="50%" rx="48%" ry="44%" fill="none" stroke={NEON_BRIGHT} strokeWidth={1.5} />
        </Svg>
      </Animated.View>

      {/* Sombra */}
      <Animated.View
        pointerEvents="none"
        style={{
          backgroundColor: "#020503",
          borderRadius: 999,
          height: shadowH0,
          left: 0,
          opacity: interp(samples.shOpacity),
          position: "absolute",
          top: 0,
          width: shadowW0,
          transform: [
            { translateX: interp(samples.shTX) },
            { translateY: interp(samples.shTY) },
            { scaleX: interp(samples.shScaleX) },
            { scaleY: interp(samples.shScaleY) }
          ]
        }}
      />

      {/* Estela */}
      <Animated.View
        pointerEvents="none"
        style={{
          left: 0,
          opacity: 0.28,
          position: "absolute",
          top: 0,
          transform: [
            { translateX: interp(samples.trailTX) },
            { translateY: interp(samples.trailTY) },
            { scale: interp(samples.trailScale) }
          ]
        }}
      >
        <Ball dia={ballDia} faint />
      </Animated.View>

      {/* Pelota */}
      <Animated.View
        pointerEvents="none"
        style={{
          left: 0,
          position: "absolute",
          top: 0,
          transform: [
            { translateX: interp(samples.ballTX) },
            { translateY: interp(samples.ballTY) },
            { scale: interp(samples.ballScale) },
            { rotate }
          ]
        }}
      >
        <Ball dia={ballDia} />
      </Animated.View>

      {/* Etiqueta */}
      {label ? (
        <View
          style={{
            backgroundColor: colors.accentFill,
            borderRadius: radii.pill,
            bottom: 0,
            boxShadow: shadows.spotlightGlow,
            paddingHorizontal: spacing.md,
            paddingVertical: 4,
            position: "absolute"
          }}
        >
          <Text style={{ ...broadcast.jersey, color: colors.onAccentFill, fontSize: 11 }}>{label}</Text>
        </View>
      ) : null}
    </View>
  );
}

/** Pelota estilizada con brillo, seam y glow neón. */
function Ball({ dia, faint = false }: { dia: number; faint?: boolean }) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: faint ? "#B6E838" : NEON_BRIGHT,
        borderRadius: dia / 2,
        height: dia,
        justifyContent: "center",
        width: dia,
        boxShadow: faint ? undefined : `0 0 ${dia * 0.7}px ${NEON}`
      }}
    >
      {!faint ? (
        <Svg width={dia} height={dia} viewBox="0 0 20 20">
          <Path d="M3 5 C 8 9, 12 9, 17 5" stroke="#F4FFDA" strokeWidth={1.1} strokeOpacity={0.85} fill="none" />
          <Path d="M3 15 C 8 11, 12 11, 17 15" stroke="#F4FFDA" strokeWidth={1.1} strokeOpacity={0.85} fill="none" />
          <Ellipse cx="7" cy="6.5" rx="3" ry="2.2" fill="#FFFFFF" fillOpacity={0.4} />
        </Svg>
      ) : null}
    </View>
  );
}

function NetMesh({ cx, netHalf, netY }: { cx: number; netHalf: number; netY: number }) {
  const strands = 9;
  const lines = [];
  for (let i = 0; i <= strands; i++) {
    const x = cx - netHalf + (i / strands) * netHalf * 2;
    lines.push(
      <Line key={i} x1={x} y1={netY} x2={x} y2={netY - netHalf * 0.16} stroke="#EAF3E4" strokeOpacity={0.16} strokeWidth={0.75} />
    );
  }
  return <>{lines}</>;
}

function toLine(a: { x: number; y: number }, b: { x: number; y: number }) {
  return { x1: a.x, y1: a.y, x2: b.x, y2: b.y };
}
