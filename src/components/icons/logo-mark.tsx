import * as React from "react";
import Svg, { Circle, Path } from "react-native-svg";

type IconProps = {
  size?: number;
};

/**
 * Logo de MatchPoint Tennis: pelota de tenis estilizada dentro de un
 * círculo verde cancha. Para splash, login y headers de marca.
 */
export function LogoMark({ size = 64 }: IconProps) {
  return (
    <Svg width={size} height={size} viewBox="0 0 64 64" fill="none">
      <Circle cx="32" cy="32" r="30" fill="#0B5E3A" />
      <Circle cx="32" cy="32" r="20" fill="#D4F542" />
      <Path
        d="M14 24C20 24 26 19 27 12"
        stroke="#0B5E3A"
        strokeWidth={2.2}
        strokeLinecap="round"
      />
      <Path
        d="M37 52C40 45 46 40 51 41"
        stroke="#0B5E3A"
        strokeWidth={2.2}
        strokeLinecap="round"
      />
    </Svg>
  );
}
