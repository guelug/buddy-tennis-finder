import { useEffect, useRef, useState } from "react";
import { Text, type TextStyle } from "react-native";

type CountUpProps = {
  value: number;
  decimals?: number;
  suffix?: string;
  style?: TextStyle;
  duration?: number;
};

/** Número animado estilo Betguate — cuenta suave hasta el valor final. */
export function CountUp({ value, decimals = 0, suffix = "", style, duration = 650 }: CountUpProps) {
  const [display, setDisplay] = useState(value);
  const prev = useRef(value);
  const raf = useRef<number>();

  useEffect(() => {
    const from = prev.current;
    const to = value;
    prev.current = value;
    if (from === to) return;

    const t0 = Date.now();
    const tick = () => {
      const p = Math.min(1, (Date.now() - t0) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(from + (to - from) * eased);
      if (p < 1) raf.current = requestAnimationFrame(tick);
      else setDisplay(to);
    };
    raf.current = requestAnimationFrame(tick);
    return () => {
      if (raf.current) cancelAnimationFrame(raf.current);
    };
  }, [value, duration]);

  const formatted =
    decimals > 0 ? display.toFixed(decimals) : Math.round(display).toString();

  return (
    <Text style={style}>
      {formatted}
      {suffix}
    </Text>
  );
}