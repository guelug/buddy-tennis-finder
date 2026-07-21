import { Text, View } from "react-native";
import { TennisBall } from "@/components/tennis-ball";
import { BROADCAST_FONTS, colors } from "@/theme";

type BrandLockupProps = {
  size?: "sm" | "md" | "lg";
  stacked?: boolean;
  light?: boolean;
};

const dimensions = {
  sm: { word: 18, ball: 17, clubs: 8, gap: 1 },
  md: { word: 25, ball: 23, clubs: 10, gap: 2 },
  lg: { word: 34, ball: 31, clubs: 12, gap: 3 }
} as const;

/** Wordmark de marca reutilizable. La pelota sustituye la O de POINT. */
export function BrandLockup({ size = "md", stacked = true, light = false }: BrandLockupProps) {
  const d = dimensions[size];
  const primary = light ? "#0F1A11" : "#F5F8F1";
  const secondary = light ? colors.court : colors.neon;

  return (
    <View accessibilityLabel="MatchPoint Tennis" style={{ alignItems: "flex-start", gap: d.gap }}>
      <View style={{ alignItems: "center", flexDirection: "row" }}>
        <BrandText color={primary} size={d.word}>MATCH</BrandText>
        <BrandText color={secondary} size={d.word}>P</BrandText>
        <View style={{ marginHorizontal: 1 }}><TennisBall animated={false} size={d.ball} /></View>
        <BrandText color={secondary} size={d.word}>INT</BrandText>
      </View>
      {stacked ? (
        <Text
          style={{
            color: secondary,
            fontFamily: BROADCAST_FONTS.extraBold,
            fontSize: d.clubs,
            fontStyle: "italic",
            fontWeight: "900",
            letterSpacing: d.clubs * 0.55,
            lineHeight: d.clubs + 2,
            marginLeft: d.word * 2.75
          }}
        >
          TENNIS
        </Text>
      ) : null}
    </View>
  );
}

function BrandText({ children, color, size }: { children: string; color: string; size: number }) {
  return (
    <Text
      style={{
        color,
        fontFamily: BROADCAST_FONTS.black,
        fontSize: size,
        fontStyle: "italic",
        fontWeight: "900",
        letterSpacing: size * 0.02,
        lineHeight: size + 2
      }}
    >
      {children}
    </Text>
  );
}
