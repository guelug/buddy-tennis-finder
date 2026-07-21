import { View } from "react-native";
import { colors } from "@/theme";

/**
 * Líneas blancas de cancha decorativas para usar como fondo en heroes.
 * Dibuja un rectángulo de cancha estilizado con líneas suaves.
 */
export function CourtLines({
  color = "rgba(255,255,255,0.14)",
  style
}: {
  color?: string;
  style?: object;
}) {
  return (
    <View
      style={[
        {
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          overflow: "hidden"
        },
        style
      ]}
    >
      <View
        style={{
          position: "absolute",
          top: "10%",
          left: "8%",
          right: "8%",
          bottom: "10%",
          borderColor: color,
          borderWidth: 1.5,
          borderRadius: 4
        }}
      />
      <View
        style={{
          position: "absolute",
          top: "10%",
          left: "50%",
          width: 1.5,
          bottom: "10%",
          backgroundColor: color
        }}
      />
      <View
        style={{
          position: "absolute",
          top: "50%",
          left: "8%",
          right: "8%",
          height: 1.5,
          backgroundColor: color
        }}
      />
      <View
        style={{
          position: "absolute",
          top: "10%",
          left: "28%",
          width: 1.5,
          bottom: "10%",
          backgroundColor: color
        }}
      />
      <View
        style={{
          position: "absolute",
          top: "10%",
          right: "28%",
          width: 1.5,
          bottom: "10%",
          backgroundColor: color
        }}
      />
    </View>
  );
}
