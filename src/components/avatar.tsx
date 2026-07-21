import * as React from "react";
import { Text, View, type ImageSourcePropType } from "react-native";
import { Image } from "expo-image";
import { colors, radii, typography, useThemeMode } from "@/theme";

type AvatarProps = {
  name: string;
  /** URL opcional de foto (se usa cuando exista en el perfil). */
  photoURL?: string | null;
  size?: number;
  /** Color de fondo del avatar si no hay foto. Se deriva del nombre por defecto. */
  backgroundSeed?: string;
};

const PLAYER_PORTRAITS: Record<string, ImageSourcePropType> = {
  "Ana Morales": require("@/../assets/generated/player-ana.webp"),
  "Carlos Rivera": require("@/../assets/generated/player-carlos.webp"),
  "María Fernanda López": require("@/../assets/generated/player-maria.webp"),
  "Diego Castillo": require("@/../assets/generated/player-diego.webp"),
  "Sofía Arévalo": require("@/../assets/generated/player-sofia.webp")
};

export function getAvatarSource(name: string, photoURL?: string | null): ImageSourcePropType | undefined {
  if (photoURL) return { uri: photoURL };
  return PLAYER_PORTRAITS[name];
}

const AVATAR_COLORS = [
  colors.court,
  colors.hardCourt,
  colors.clay,
  colors.grass,
  "#5C6BC0",
  "#8D6E63",
  "#7B1FA2",
  "#00897B"
];

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function colorFor(seed: string) {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = seed.charCodeAt(i) + ((hash << 5) - hash);
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

/**
 * Avatar circular con iniciales sobre fondo derivado del nombre.
 * Cuando photoURL esté disponible en el perfil, se mostrará la imagen
 * (con expo-image y placeholder de iniciales).
 */
export function Avatar({ name, photoURL, size = 48, backgroundSeed }: AvatarProps) {
  const { isLight } = useThemeMode();
  const bg = colorFor(backgroundSeed ?? name);
  const source = getAvatarSource(name, photoURL);
  const ringLight = "rgba(255,255,255,0.90)";
  const ringDark = "rgba(234,243,228,0.24)";

  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: bg,
        borderRadius: size / 2,
        height: size,
        justifyContent: "center",
        width: size,
        borderWidth: 2.5,
        borderColor: isLight ? ringLight : ringDark,
        boxShadow: isLight
          ? "0 2px 8px -2px rgba(27,55,36,0.22)"
          : "0 2px 10px -2px rgba(0,0,0,0.30), inset 0 0 0 1px rgba(255,255,255,0.06)",
        shadowColor: "rgba(0,0,0,0.20)",
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.2,
        shadowRadius: 4,
        overflow: "hidden"
      }}
    >
      {source ? (
        <Image
          accessibilityLabel={`Foto de ${name}`}
          source={source}
          contentFit="cover"
          // Fade-in suave al cargar + caché en disco: las fotos dejan de
          // "aparecer de golpe" al navegar entre pantallas.
          transition={180}
          cachePolicy="memory-disk"
          style={{ height: "100%", width: "100%" }}
        />
      ) : (
        <Text
          style={{
            ...typography.headline,
            color: "#FFFFFF",
            fontSize: size * 0.38,
            fontWeight: "800"
          }}
        >
          {initials(name)}
        </Text>
      )}
    </View>
  );
}
