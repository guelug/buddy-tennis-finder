import * as React from "react";
import { Platform, type ColorValue } from "react-native";
import { SymbolView, type SymbolViewProps } from "expo-symbols";
import Svg, { Circle, Line, Path, Polygon, Polyline, Rect } from "react-native-svg";

/**
 * Icono multiplataforma. En iOS usa SF Symbols nativos; en Android/web
 * renderiza SVGs propios (antes los fallbacks eran emojis y en web se veía mal).
 */
export type IconName =
  | "tennis"
  | "calendar"
  | "calendar-clock"
  | "calendar-plus"
  | "user"
  | "users"
  | "map-pin"
  | "clock"
  | "location"
  | "send"
  | "check"
  | "check-badge"
  | "star"
  | "zap"
  | "building"
  | "globe"
  | "pencil"
  | "sign-out"
  | "trophy"
  | "search"
  | "close"
  | "sliders"
  | "chevron-right";

type IconProps = {
  name: IconName;
  size?: number;
  color?: ColorValue;
  /** Peso visual (solo afecta el grosor del trazo en SVG). */
  weight?: "regular" | "bold";
};

/** Mapeo a SF Symbols para iOS. */
const SF_NAMES: Record<IconName, SymbolViewProps["name"]> = {
  tennis: "figure.tennis",
  calendar: "calendar",
  "calendar-clock": "calendar.badge.clock",
  "calendar-plus": "calendar.badge.plus",
  user: "person.crop.circle.fill",
  users: "person.2.fill",
  "map-pin": "mappin.and.ellipse",
  clock: "clock.fill",
  location: "location.fill",
  send: "paperplane.fill",
  check: "checkmark",
  "check-badge": "checkmark.seal.fill",
  star: "star.fill",
  zap: "bolt.fill",
  building: "building.2.fill",
  globe: "globe",
  pencil: "pencil",
  "sign-out": "rectangle.portrait.and.arrow.right",
  trophy: "trophy.fill",
  search: "magnifyingglass",
  close: "xmark",
  sliders: "slider.horizontal.3",
  "chevron-right": "chevron.right"
};

export function Icon({ name, size = 20, color = "#0B5E3A", weight = "regular" }: IconProps) {
  if (Platform.OS === "ios") {
    return (
      <SymbolView
        name={SF_NAMES[name]}
        size={size}
        tintColor={color}
        weight={weight === "bold" ? "bold" : "regular"}
      />
    );
  }

  const strokeWidth = weight === "bold" ? 2.4 : 2;
  const common = {
    stroke: color,
    strokeWidth,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    fill: "none" as const
  };

  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      {renderGlyph(name, common)}
    </Svg>
  );
}

type StrokeProps = {
  stroke: ColorValue;
  strokeWidth: number;
  strokeLinecap: "round";
  strokeLinejoin: "round";
  fill: "none";
};

function renderGlyph(name: IconName, s: StrokeProps) {
  switch (name) {
    case "tennis":
      return (
        <>
          <Circle cx="12" cy="12" r="9.2" {...s} />
          <Path d="M5 5.8C8.4 8 8.4 16 5 18.2" {...s} />
          <Path d="M19 5.8C15.6 8 15.6 16 19 18.2" {...s} />
        </>
      );
    case "calendar":
      return (
        <>
          <Rect x="3" y="4.5" width="18" height="17" rx="2.5" {...s} />
          <Line x1="16" y1="2.5" x2="16" y2="6.5" {...s} />
          <Line x1="8" y1="2.5" x2="8" y2="6.5" {...s} />
          <Line x1="3" y1="10" x2="21" y2="10" {...s} />
        </>
      );
    case "calendar-clock":
      return (
        <>
          <Rect x="3" y="4.5" width="18" height="17" rx="2.5" {...s} />
          <Line x1="16" y1="2.5" x2="16" y2="6.5" {...s} />
          <Line x1="8" y1="2.5" x2="8" y2="6.5" {...s} />
          <Line x1="3" y1="10" x2="21" y2="10" {...s} />
          <Path d="M12 13v3l2 1.4" {...s} />
        </>
      );
    case "calendar-plus":
      return (
        <>
          <Rect x="3" y="4.5" width="18" height="17" rx="2.5" {...s} />
          <Line x1="16" y1="2.5" x2="16" y2="6.5" {...s} />
          <Line x1="8" y1="2.5" x2="8" y2="6.5" {...s} />
          <Line x1="3" y1="10" x2="21" y2="10" {...s} />
          <Line x1="12" y1="13.5" x2="12" y2="18.5" {...s} />
          <Line x1="9.5" y1="16" x2="14.5" y2="16" {...s} />
        </>
      );
    case "user":
      return (
        <>
          <Path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" {...s} />
          <Circle cx="12" cy="7" r="4" {...s} />
        </>
      );
    case "users":
      return (
        <>
          <Path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" {...s} />
          <Circle cx="9" cy="7" r="4" {...s} />
          <Path d="M23 21v-2a4 4 0 0 0-3-3.87" {...s} />
          <Path d="M16 3.13a4 4 0 0 1 0 7.75" {...s} />
        </>
      );
    case "map-pin":
      return (
        <>
          <Path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" {...s} />
          <Circle cx="12" cy="10" r="3" {...s} />
        </>
      );
    case "clock":
      return (
        <>
          <Circle cx="12" cy="12" r="10" {...s} />
          <Polyline points="12 6 12 12 16 14" {...s} />
        </>
      );
    case "location":
      return <Polygon points="3 11 22 2 13 21 11 13 3 11" {...s} />;
    case "send":
      return (
        <>
          <Line x1="22" y1="2" x2="11" y2="13" {...s} />
          <Polygon points="22 2 15 22 11 13 2 9 22 2" {...s} />
        </>
      );
    case "check":
      return <Polyline points="20 6 9 17 4 12" {...s} />;
    case "check-badge":
      return (
        <>
          <Path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" {...s} />
          <Polyline points="22 4 12 14.01 9 11.01" {...s} />
        </>
      );
    case "star":
      return (
        <Polygon
          points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"
          {...s}
          fill={s.stroke}
        />
      );
    case "zap":
      return <Polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" {...s} fill={s.stroke} />;
    case "building":
      return (
        <>
          <Line x1="2" y1="22" x2="22" y2="22" {...s} />
          <Path d="M5 22V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v17" {...s} />
          <Line x1="9" y1="7" x2="9" y2="7.01" {...s} />
          <Line x1="15" y1="7" x2="15" y2="7.01" {...s} />
          <Line x1="9" y1="11" x2="9" y2="11.01" {...s} />
          <Line x1="15" y1="11" x2="15" y2="11.01" {...s} />
          <Path d="M10 22v-4h4v4" {...s} />
        </>
      );
    case "globe":
      return (
        <>
          <Circle cx="12" cy="12" r="10" {...s} />
          <Line x1="2" y1="12" x2="22" y2="12" {...s} />
          <Path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" {...s} />
        </>
      );
    case "pencil":
      return <Path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z" {...s} />;
    case "sign-out":
      return (
        <>
          <Path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" {...s} />
          <Polyline points="16 17 21 12 16 7" {...s} />
          <Line x1="21" y1="12" x2="9" y2="12" {...s} />
        </>
      );
    case "trophy":
      return (
        <>
          <Path d="M8 21h8" {...s} />
          <Path d="M12 17v4" {...s} />
          <Path d="M6 3h12v6a6 6 0 0 1-12 0V3z" {...s} />
          <Path d="M6 5H3v2a4 4 0 0 0 3 3.87" {...s} />
          <Path d="M18 5h3v2a4 4 0 0 1-3 3.87" {...s} />
        </>
      );
    case "search":
      return (
        <>
          <Circle cx="11" cy="11" r="8" {...s} />
          <Line x1="21" y1="21" x2="16.65" y2="16.65" {...s} />
        </>
      );
    case "close":
      return (
        <>
          <Line x1="6" y1="6" x2="18" y2="18" {...s} />
          <Line x1="18" y1="6" x2="6" y2="18" {...s} />
        </>
      );
    case "sliders":
      return (
        <>
          <Line x1="4" y1="6" x2="20" y2="6" {...s} />
          <Line x1="4" y1="12" x2="20" y2="12" {...s} />
          <Line x1="4" y1="18" x2="20" y2="18" {...s} />
          <Circle cx="8" cy="6" r="2" {...s} fill={s.stroke} />
          <Circle cx="16" cy="12" r="2" {...s} fill={s.stroke} />
          <Circle cx="10" cy="18" r="2" {...s} fill={s.stroke} />
        </>
      );
    case "chevron-right":
      return <Polyline points="9 18 15 12 9 6" {...s} />;
  }
}
