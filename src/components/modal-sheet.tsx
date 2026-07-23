import * as React from "react";
import { BackHandler, Pressable, ScrollView, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { colors, mobileTabBar, radii, shadows, spacing, useBreakpoint } from "@/theme";
import { useI18n } from "@/lib/i18n";

type ModalSheetProps = {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  /** Ancho máximo del diálogo en pantallas anchas. Default 520. */
  maxWidth?: number;
};

/**
 * Contenedor de sobreposición adaptativo:
 *  - Móvil: bottom sheet con grabber y esquinas superiores redondeadas.
 *  - Tablet/desktop: diálogo centrado (card flotante).
 *
 * Se renderiza dentro de la pantalla, sin crear una segunda ventana nativa.
 * Esto evita el fallo de Android/React Native que deja algunos Modal
 * transparentes capturando todos los toques.
 */
export function ModalSheet({ visible, onClose, children, maxWidth = 520 }: ModalSheetProps) {
  const { isWide } = useBreakpoint();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  React.useEffect(() => {
    if (!visible) return;
    const subscription = BackHandler.addEventListener("hardwareBackPress", () => {
      onClose();
      return true;
    });
    return () => subscription.remove();
  }, [onClose, visible]);

  if (!visible) return null;

  return (
    <View
      style={{
        alignItems: isWide ? "center" : "stretch",
        backgroundColor: "rgba(6,18,10,0.72)",
        bottom: 0,
        elevation: 100,
        justifyContent: isWide ? "center" : "flex-end",
        left: 0,
        padding: isWide ? spacing.xl : 0,
        position: "absolute",
        right: 0,
        top: 0,
        zIndex: 1000
      }}
    >
      <Pressable accessibilityLabel={t("common.closePanel")} style={{ bottom: 0, left: 0, position: "absolute", right: 0, top: 0 }} onPress={onClose} />
      <View
        style={{
          backgroundColor: colors.surface,
          borderTopLeftRadius: radii.xl,
          borderTopRightRadius: radii.xl,
          borderBottomLeftRadius: isWide ? radii.xl : 0,
          borderBottomRightRadius: isWide ? radii.xl : 0,
          boxShadow: shadows.floating,
          maxHeight: isWide ? "88%" : "92%",
          maxWidth: isWide ? maxWidth : undefined,
          overflow: "hidden",
          width: isWide ? "100%" : undefined
        }}
      >
        {!isWide ? (
          <View
            style={{
              alignSelf: "center",
              backgroundColor: colors.borderStrong,
              borderRadius: radii.pill,
              height: 5,
              marginBottom: spacing.xs,
              marginTop: spacing.sm,
              width: 40
            }}
          />
        ) : null}
        <ScrollView
          contentContainerStyle={{
            padding: spacing.lg,
            paddingBottom: isWide
              ? spacing.lg
              : Math.max(spacing.xxl, insets.bottom + mobileTabBar.contentClearance * 2 + spacing.lg)
          }}
          keyboardDismissMode="on-drag"
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {children}
        </ScrollView>
      </View>
    </View>
  );
}
