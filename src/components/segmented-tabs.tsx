import * as React from "react";
import { Pressable, Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { colors, radii, spacing, typography } from "@/theme";

type SegmentedTab<T extends string> = {
  id: T;
  label: string;
  count?: number;
};

type SegmentedTabsProps<T extends string> = {
  tabs: SegmentedTab<T>[];
  value: T;
  onChange: (value: T) => void;
};

/** Control segmentado estilo iOS para filtrar listas. */
export function SegmentedTabs<T extends string>({ tabs, value, onChange }: SegmentedTabsProps<T>) {
  return (
    <View
      style={{
        backgroundColor: colors.surfaceElevated,
        borderColor: colors.border,
        borderCurve: "continuous",
        borderRadius: radii.md,
        borderWidth: 1,
        flexDirection: "row",
        padding: 3
      }}
    >
      {tabs.map((tab) => {
        const active = tab.id === value;
        return (
          <Pressable
            key={tab.id}
            onPress={() => {
              if (process.env.EXPO_OS === "ios") Haptics.selectionAsync();
              onChange(tab.id);
            }}
            style={{
              alignItems: "center",
              borderRadius: radii.sm,
              flex: 1,
              flexDirection: "row",
              gap: spacing.xs,
              justifyContent: "center",
              overflow: "hidden",
              paddingVertical: spacing.sm,
              position: "relative"
            }}
          >
            {active ? (
              <Animated.View
                entering={FadeIn.duration(120)}
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                  borderCurve: "continuous",
                  borderRadius: radii.sm,
                  borderWidth: 1,
                  bottom: 0,
                  left: 0,
                  position: "absolute",
                  right: 0,
                  top: 0,
                  boxShadow: "0 1px 3px rgba(11,26,18,0.08)"
                }}
              />
            ) : null}
            <Text
              style={{
                ...typography.caption,
                color: active ? colors.textPrimary : colors.textSecondary,
                fontSize: 13,
                fontWeight: active ? "700" : "600",
                zIndex: 1
              }}
            >
              {tab.label}
            </Text>
            {tab.count !== undefined && tab.count > 0 ? (
              <View
                style={{
                  backgroundColor: active ? colors.court : colors.courtLight,
                  borderRadius: radii.pill,
                  minWidth: 20,
                  paddingHorizontal: 6,
                  paddingVertical: 2,
                  zIndex: 1
                }}
              >
                <Text
                  style={{
                    ...typography.footnote,
                    color: active ? colors.textOnBrand : colors.court,
                    fontSize: 11,
                    fontWeight: "800",
                    textAlign: "center"
                  }}
                >
                  {tab.count}
                </Text>
              </View>
            ) : null}
          </Pressable>
        );
      })}
    </View>
  );
}