import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { TennisBall } from "@/components/tennis-ball";
import { colors, spacing, typography } from "@/theme";

/** Pantalla de carga global con pelota girando. */
export function LoadingView() {
  return (
    <Animated.View
      entering={FadeIn.duration(300)}
      style={{
        alignItems: "center",
        backgroundColor: colors.background,
        flex: 1,
        justifyContent: "center",
        gap: spacing.md,
        padding: spacing.base
      }}
    >
      <TennisBall size={48} animated />
      <Text style={{ ...typography.body, color: colors.textSecondary }}>Cargando...</Text>
    </Animated.View>
  );
}
