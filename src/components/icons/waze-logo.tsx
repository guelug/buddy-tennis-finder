import * as React from "react";
import Svg, { Circle, Path } from "react-native-svg";

type Props = {
  size?: number;
  /** "brand" = filled Waze-blue badge (recommended). "mono" = single color. */
  variant?: "brand" | "mono";
  color?: string;
};

/**
 * Official Waze navigation mark, redrawn from the published Waze SVG path
 * data so it stays sharp at every size and on both native/web renderers.
 */
export function WazeLogo({ size = 22, variant = "brand", color = "#FFFFFF" }: Props) {
  if (variant === "mono") {
    return (
      <Svg width={size} height={size} viewBox="0 0 50 52" fill="none">
        <Path d={OFFICIAL_WAZE_OUTLINE} fill="none" stroke={color} strokeWidth="2.2" strokeLinejoin="round" />
        <Circle cx="22.5" cy="15.035" r="1.7" fill={color} />
        <Circle cx="37.5" cy="15.035" r="1.7" fill={color} />
        <Path d="M22.1 25c-.9 0-1.5.9-1.1 1.7 1.7 3.5 5.1 5.7 9 5.7s7.4-2.2 9-5.7c.4-.8-.2-1.7-1.1-1.7-.5 0-.9.3-1.1.7-1.2 2.6-3.9 4.2-6.8 4.2s-5.5-1.6-6.7-4.2c-.2-.4-.6-.7-1.2-.7Z" fill={color} />
      </Svg>
    );
  }

  return (
    <Svg width={size} height={size} viewBox="0 0 50 52" fill="none">
      <Path d={OFFICIAL_WAZE_OUTLINE} fill="#111A16" />
      <Path d={OFFICIAL_WAZE_INNER} fill="#FFFFFF" />
      <Circle cx="22.5" cy="15.035" r="2.5" fill="#111A16" />
      <Circle cx="37.5" cy="15.035" r="2.5" fill="#111A16" />
      <Path d="M22.1 25c-.9 0-1.5.9-1.1 1.7 1.7 3.5 5.1 5.7 9 5.7s7.4-2.2 9-5.7c.4-.8-.2-1.7-1.1-1.7-.5 0-.9.3-1.1.7-1.2 2.6-3.9 4.2-6.8 4.2s-5.5-1.6-6.7-4.2c-.2-.4-.6-.7-1.2-.7Z" fill="#111A16" />
      <Circle cx="16.3" cy="44.2" r="3" fill="#111A16" />
      <Circle cx="33.7" cy="44.2" r="3" fill="#111A16" />
    </Svg>
  );
}

const OFFICIAL_WAZE_INNER = "M27.5 2.674C21.319 2.674 15.556 5.451 11.667 10.382 8.958 13.854 7.5 18.16 7.5 22.535v3.68c0 1.597-.625 3.125-1.667 4.236-.833.834-1.875 1.459-2.986 1.737.417 1.041 1.389 2.638 3.125 4.375 1.459 1.527 3.195 2.777 5.07 3.68v-.069c1.18-1.806 3.125-2.848 5.277-2.848.417 0 .764.07 1.181.139 2.5.486 4.444 2.431 4.931 4.861h5.138c5.348 0 10.417-2.222 14.098-5.833 5.694-5.694 7.43-14.236 3.75-21.597C42.847 7.465 35.625 2.674 27.5 2.674Z";
const OFFICIAL_WAZE_OUTLINE = "M27.5 .174C20.625 .174 14.167 3.229 9.792 8.715 6.667 12.674 5 17.535 5 22.604v3.611c0 1.875-1.319 3.611-3.889 3.75-.625 0-1.111.486-1.18 1.111-.07 1.667 1.736 4.792 4.236 7.292 1.736 1.736 3.75 3.125 5.902 4.236-.694 3.82 2.292 7.292 6.181 7.292h.069c2.987 0 5.487-2.083 6.112-4.931h5.208c.555 2.848 3.055 4.931 6.111 4.931.694 0 1.458-.139 2.153-.347 1.736-.556 3.055-1.875 3.68-3.612.556-1.597.486-3.194 0-4.513 1.389-.903 2.639-1.875 3.82-3.056C47.639 34.201 50 28.507 50 22.604c0-5.972-2.361-11.528-6.597-15.764C39.167 2.465 33.472 .174 27.5 .174Z";
