import { PropsWithChildren } from "react";
import { ScrollView, View } from "react-native";
import { colors, contentWidth, spacing } from "@/theme";
import { usePlatformLayout } from "@/theme/platform";

type ShellWidth = keyof typeof contentWidth;

type WebShellProps = PropsWithChildren<{
  width?: ShellWidth;
}>;

/** Contenedor optimizado para web — más aire, ancho amplio, sin insets de tab bar. */
export function WebShell({ children, width = "wide" }: WebShellProps) {
  const { isWebDesktop } = usePlatformLayout();

  return (
    <ScrollView
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
      nestedScrollEnabled
      showsVerticalScrollIndicator={false}
      style={{ alignSelf: "stretch", backgroundColor: "transparent", flex: 1, minWidth: 0, overscrollBehaviorY: "contain", touchAction: "pan-y", width: "100%" } as object}
      contentContainerStyle={{
        alignItems: "center",
        alignSelf: "stretch",
        paddingBottom: isWebDesktop ? 72 : spacing.xxxl,
        paddingHorizontal: isWebDesktop ? spacing.xxxl : spacing.xl,
        paddingTop: isWebDesktop ? 36 : spacing.xl,
        width: "100%"
      }}
    >
      <View style={{ alignSelf: "center", gap: isWebDesktop ? spacing.xl : spacing.lg, maxWidth: contentWidth[width], minWidth: 0, width: "100%" }}>{children}</View>
    </ScrollView>
  );
}
