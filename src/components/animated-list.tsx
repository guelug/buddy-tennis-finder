import * as React from "react";
import { View, type ViewStyle } from "react-native";
import Animated, { FadeInUp } from "react-native-reanimated";
import { spacing } from "@/theme";

type AnimatedListProps = {
  children: React.ReactNode;
  gap?: keyof typeof spacing;
  stagger?: number;
  style?: ViewStyle;
};

/**
 * Envuelve hijos directos con entradas escalonadas FadeInUp.
 * Ideal para listas y cards. En Android, las animaciones de entering
 * funcionan si se usa `skipEntering={false}` en padres, o se configura
 * `LayoutAnimationConfig` adecuadamente.
 */
export function AnimatedList({ children, gap = "base", stagger = 60, style }: AnimatedListProps) {
  const items = React.Children.toArray(children).filter(Boolean);
  return (
    <View style={[{ gap: spacing[gap] }, style]}>
      {items.map((child, index) => (
        <Animated.View
          key={index}
          entering={FadeInUp.delay(index * stagger).duration(320).springify()}
        >
          {child}
        </Animated.View>
      ))}
    </View>
  );
}
