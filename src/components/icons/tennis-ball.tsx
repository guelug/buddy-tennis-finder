import * as React from "react";
import Svg, { Circle, Path } from "react-native-svg";

type IconProps = {
  size?: number;
  color?: string;
};

/** Pelota de tenis con la curva característica. Usada en branding y splash. */
export function TennisBall({ size = 24, color = "#D4F542" }: IconProps) {
  return (
    <Svg width={size} height={size} viewBox="0 0 48 48" fill="none">
      <Circle cx="24" cy="24" r="22" fill={color} />
      <Path
        d="M3 18C10 18 17 12 19 3"
        stroke="#0B5E3A"
        strokeWidth={2.4}
        strokeLinecap="round"
        opacity={0.85}
      />
      <Path
        d="M29 45C32 36 39 30 45 30"
        stroke="#0B5E3A"
        strokeWidth={2.4}
        strokeLinecap="round"
        opacity={0.85}
      />
    </Svg>
  );
}
