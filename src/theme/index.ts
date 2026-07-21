import { colors, brand, radii, spacing, shadows, motion } from "./tokens";
import { typography, broadcast, BROADCAST_FONTS, type TextStyle } from "./typography";

export { colors, brand, radii, spacing, shadows, motion } from "./tokens";
export { typography, broadcast, BROADCAST_FONT, BROADCAST_FONTS, type TextStyle } from "./typography";
export {
  breakpoints,
  contentWidth,
  mobileTabBar,
  statusBarTopInset,
  useBreakpoint,
  useTabBarScrollPadding,
  useScreenSafePadding,
  type Breakpoint
} from "./layout";
export { usePlatformLayout } from "./platform";
export { ThemeModeProvider, useThemeMode, type ThemePreference } from "./theme-mode";

/**
 * Hook de conveniencia para acceder al tema en componentes.
 */
export function useTheme() {
  return {
    colors,
    brand,
    radii,
    spacing,
    shadows,
    motion,
    typography,
    broadcast
  };
}
