import { PropsWithChildren, useCallback, useState } from "react";
import { Platform, RefreshControl, ScrollView, View } from "react-native";
import { colors, contentWidth, spacing, useBreakpoint, useScreenSafePadding, useTabBarScrollPadding } from "@/theme";

type ShellWidth = keyof typeof contentWidth;

type ScreenShellProps = PropsWithChildren<{
  /** Ancho máximo del contenido en pantallas grandes. Default `base` (640). */
  width?: ShellWidth;
  /**
   * Padding inferior extra por encima del clearance del tab bar.
   * En móvil el tab bar se calcula con safe-area real; este valor solo suma aire.
   */
  bottomInset?: number;
  /**
   * Añade padding superior según el notch/status bar.
   * Usar en pantallas sin header nativo (p. ej. perfil público, onboarding).
   */
  topSafe?: boolean;
  /** Recarga de datos al tirar hacia abajo (pull-to-refresh nativo). */
  onRefresh?: () => Promise<unknown> | void;
}>;

/**
 * Contenedor de pantalla: en móvil ocupa todo el ancho; en tablet/desktop
 * centra el contenido con un ancho máximo para que la app no se "estire"
 * en ventanas grandes de web.
 *
 * El padding inferior se adapta a insets del sistema + tab bar flotante
 * para que botones (Cómo llegar, Perfil, etc.) no queden tapados en
 * móviles con gestos o pantallas estrechas.
 */
export function ScreenShell({
  children,
  width = "base",
  bottomInset = 0,
  topSafe = false,
  onRefresh
}: ScreenShellProps) {
  const { isWide } = useBreakpoint();
  const tabPadding = useTabBarScrollPadding(bottomInset);
  const safe = useScreenSafePadding();
  const safeBottom = isWide ? Math.max(40, bottomInset || 32) : tabPadding;
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = useCallback(async () => {
    if (!onRefresh) return;
    setRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setRefreshing(false);
    }
  }, [onRefresh]);

  return (
    <ScrollView
      // iOS no aparta el contenido al abrirse el teclado: sin esto, en las
      // pantallas con formulario (registrar dobles, anuncio de entrenador,
      // ligas privadas) el campo enfocado se quedaba debajo del teclado.
      // Android ya lo resuelve con adjustResize.
      automaticallyAdjustKeyboardInsets
      contentInsetAdjustmentBehavior="automatic"
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
      nestedScrollEnabled
      showsVerticalScrollIndicator={false}
      refreshControl={
        onRefresh ? (
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            tintColor={colors.neon as string}
            colors={[colors.neon as string]}
            progressBackgroundColor={colors.surfaceElevated as string}
          />
        ) : undefined
      }
      style={[
        { backgroundColor: "transparent", flex: 1 },
        Platform.OS === "web" ? ({ overscrollBehaviorY: "contain", touchAction: "pan-y" } as object) : null
      ]}
      contentContainerStyle={{
        paddingHorizontal: isWide ? spacing.xl : spacing.base,
        paddingTop: topSafe ? Math.max(safe.top, spacing.sm) + spacing.sm : 0,
        paddingBottom: safeBottom,
        alignItems: "center"
      }}
    >
      <View
        style={{
          width: "100%",
          maxWidth: contentWidth[width],
          gap: spacing.lg
        }}
      >
        {children}
      </View>
    </ScrollView>
  );
}
