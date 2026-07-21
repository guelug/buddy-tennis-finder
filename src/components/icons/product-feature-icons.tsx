import * as React from "react";
import Svg, { Circle, Line, Path, Rect, Polyline } from "react-native-svg";
import { colors } from "@/theme";

export type ProductFeatureIconName =
  | "app"
  | "ranking-live"
  | "rival-radar"
  | "match-control"
  | "rival-validation"
  | "team-builder"
  | "player-profile";

type ProductFeatureIconProps = {
  name: ProductFeatureIconName;
  size?: number;
  tone?: "dark" | "light";
  accent?: string;
};

export function ProductFeatureIcon({
  name,
  size = 40,
  tone = "dark",
  accent = colors.neon
}: ProductFeatureIconProps) {
  const bg = tone === "light" ? "#FFFFFF" : "#102016";
  const fg = tone === "light" ? "#4D8F19" : accent;
  const muted = tone === "light" ? "rgba(77,143,25,0.22)" : "rgba(198,241,53,0.18)";

  return (
    <Svg width={size} height={size} viewBox="0 0 48 48" fill="none">
      <Rect x="2" y="2" width="44" height="44" rx="14" fill={bg} stroke={muted} strokeWidth="1.4" />
      {renderProductGlyph(name, fg, muted)}
    </Svg>
  );
}

function renderProductGlyph(name: ProductFeatureIconName, fg: string, muted: string) {
  switch (name) {
    case "app":
      return (
        <>
          <Circle cx="24" cy="24" r="11" fill={fg} opacity="0.95" />
          <Path d="M15 22c5.4-1.1 8.3-4.4 9.7-9" stroke="#FFFFFF" strokeWidth="2.2" strokeLinecap="round" />
          <Path d="M33 26c-5.4 1.1-8.3 4.4-9.7 9" stroke="#FFFFFF" strokeWidth="2.2" strokeLinecap="round" />
          <Path d="M15 31c6.8 1.2 13.6-2.2 18-9" stroke="#FFFFFF" strokeWidth="1.7" strokeLinecap="round" opacity="0.82" />
        </>
      );
    case "ranking-live":
      return (
        <>
          <Rect x="13" y="27" width="5.5" height="8" rx="1.5" fill={fg} />
          <Rect x="21.2" y="22" width="5.5" height="13" rx="1.5" fill={fg} opacity="0.82" />
          <Rect x="29.4" y="16" width="5.5" height="19" rx="1.5" fill={fg} opacity="0.66" />
          <Polyline points="13 22 21 17 26 20 35 10" stroke={fg} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M31 10h4v4" stroke={fg} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
        </>
      );
    case "rival-radar":
      return (
        <>
          <Circle cx="24" cy="24" r="13" stroke={fg} strokeWidth="2" opacity="0.9" />
          <Circle cx="24" cy="24" r="6.5" stroke={fg} strokeWidth="1.6" opacity="0.55" />
          <Line x1="24" y1="7" x2="24" y2="12" stroke={fg} strokeWidth="2" strokeLinecap="round" />
          <Line x1="24" y1="36" x2="24" y2="41" stroke={fg} strokeWidth="2" strokeLinecap="round" />
          <Line x1="7" y1="24" x2="12" y2="24" stroke={fg} strokeWidth="2" strokeLinecap="round" />
          <Line x1="36" y1="24" x2="41" y2="24" stroke={fg} strokeWidth="2" strokeLinecap="round" />
          <Path d="M24 24 34 15" stroke={fg} strokeWidth="3" strokeLinecap="round" />
          <Circle cx="24" cy="24" r="2.6" fill={fg} />
        </>
      );
    case "match-control":
      return (
        <>
          <Rect x="12" y="12" width="24" height="24" rx="4" stroke={fg} strokeWidth="2.2" />
          <Line x1="24" y1="12" x2="24" y2="36" stroke={fg} strokeWidth="1.6" opacity="0.7" />
          <Line x1="12" y1="24" x2="36" y2="24" stroke={fg} strokeWidth="1.6" opacity="0.7" />
          <Path d="M17 18h4M17 30h4M28 18h4M28 30h4" stroke={fg} strokeWidth="2.4" strokeLinecap="round" />
        </>
      );
    case "rival-validation":
      return (
        <>
          <Path d="M24 9 35 14v8.4c0 7.1-4.4 12.2-11 15.6-6.6-3.4-11-8.5-11-15.6V14l11-5Z" stroke={fg} strokeWidth="2.4" strokeLinejoin="round" fill={muted} />
          <Polyline points="18 24 22 28 31 19" stroke={fg} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        </>
      );
    case "team-builder":
      return (
        <>
          <Circle cx="24" cy="18" r="5.2" fill={fg} />
          <Circle cx="15.5" cy="22" r="4.3" fill={fg} opacity="0.72" />
          <Circle cx="32.5" cy="22" r="4.3" fill={fg} opacity="0.72" />
          <Path d="M13 35c1.7-5.2 5.4-8 11-8s9.3 2.8 11 8" fill={fg} />
          <Path d="M8.5 35c1.1-4.1 3.7-6.5 7.8-7.1" stroke={fg} strokeWidth="3" strokeLinecap="round" opacity="0.72" />
          <Path d="M39.5 35c-1.1-4.1-3.7-6.5-7.8-7.1" stroke={fg} strokeWidth="3" strokeLinecap="round" opacity="0.72" />
        </>
      );
    case "player-profile":
      return (
        <>
          <Circle cx="24" cy="18.5" r="6.6" fill={fg} />
          <Path d="M13 36c1.7-6.6 5.4-10.2 11-10.2S33.3 29.4 35 36" fill={fg} opacity="0.9" />
          <Circle cx="24" cy="24" r="15" stroke={fg} strokeWidth="1.8" opacity="0.5" />
        </>
      );
  }
}
