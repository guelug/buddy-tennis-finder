import { useEffect } from "react";
import { useFonts } from "expo-font";
import { BROADCAST_FONTS } from "@/theme";

/**
 * Carga las fuentes broadcast (Saira Condensed) de forma asíncrona.
 * Devuelve `loaded` (booleano) que el AuthGate puede usar para mostrar un
 * splash controlado mientras cargan.
 *
 * Las fuentes viven en /assets/fonts y se cargan vía metro (no requieren
 * configuración nativa ni plugin de Expo).
 */
export function useAppFonts(): boolean {
  const [loaded, error] = useFonts({
    [BROADCAST_FONTS.semiBold]: require("@/../assets/fonts/SairaCondensed-SemiBold.ttf"),
    [BROADCAST_FONTS.extraBold]: require("@/../assets/fonts/SairaCondensed-ExtraBold.ttf"),
    [BROADCAST_FONTS.black]: require("@/../assets/fonts/SairaCondensed-Black.ttf")
  });

  useEffect(() => {
    if (error) {
      console.warn("[matchpoint] No se pudieron cargar las fuentes; se usarán las del sistema.", error);
    }
  }, [error]);

  // Un recurso tipográfico nunca debe bloquear toda la interfaz.
  return loaded || Boolean(error);
}
