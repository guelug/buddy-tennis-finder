import * as React from "react";
import { View } from "react-native";
import { spacing } from "@/theme";
import { usePlatformLayout } from "@/theme/platform";

type ContentGridProps = {
  children: React.ReactNode;
  /** Columnas en desktop web. Default 2. */
  columns?: 1 | 2 | 3;
};

/** Grilla responsiva para tarjetas en web. */
export function ContentGrid({ children, columns = 2 }: ContentGridProps) {
  const { isWebDesktop, isWebWide } = usePlatformLayout();
  const cols = isWebDesktop ? columns : isWebWide ? Math.min(columns, 2) : 1;
  const itemWidth = cols === 1 ? "100%" : cols === 2 ? "48%" : "31%";

  const itemStyle = {
    flexGrow: 1,
    width: itemWidth as `${number}%`
  };

  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
      {React.Children.map(children, (child, index) =>
        child ? (
          <View key={index} style={itemStyle}>
            {child}
          </View>
        ) : null
      )}
    </View>
  );
}