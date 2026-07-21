import { Linking, Alert, Platform } from "react-native";

/**
 * Abre Waze navegando a unas coordenadas. Si Waze no está instalado,
 * abre el navegador con la URL universal de Waze (que a su vez ofrece
 * abrir la app o usar la versión web).
 *
 * Documentación: https://developers.google.com/waze/deeplinks
 */
export async function openInWaze(latitude: number, longitude: number, label?: string) {
  // URL universal: funciona en iOS, Android y web. Si la app está instalada,
  // la abre directamente; si no, abre la versión web.
  const url = `https://waze.com/ul?ll=${latitude}%2C${longitude}&navigate=yes${label ? `&q=${encodeURIComponent(label)}` : ""}`;

  try {
    // No usamos canOpenURL: en Android 11+ devuelve false para URLs https
    // ajenas sin declarar <queries>, y el botón fallaba con Waze instalado.
    await Linking.openURL(url);
    return true;
  } catch (error) {
    // Fallback: mostrar el error y ofrecer copiar la URL.
    Alert.alert(
      "No pudimos abrir Waze",
      Platform.OS === "web"
        ? "Verifica que Waze esté instalado o usa Google Maps."
        : "Es posible que Waze no esté instalado en este dispositivo.",
      [{ text: "OK" }]
    );
    return false;
  }
}
