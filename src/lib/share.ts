import { Platform, Share } from "react-native";
import { Asset } from "expo-asset";
import * as Sharing from "expo-sharing";
import type { PrivateLeague } from "@/types";

export const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.matchpoint.clubs";
export const WEB_APP_URL = process.env.EXPO_PUBLIC_APP_URL || "https://tennisleagueapp.win";
export const APP_STORE_URL = process.env.EXPO_PUBLIC_APP_STORE_URL || WEB_APP_URL;
export type CommunityShareFormat = "story" | "reel" | "post" | "message";

const COMMUNITY_BANNERS = {
  story: require("@/../assets/share/matchpoint-share-story-v2.png"),
  reel: require("@/../assets/share/matchpoint-share-reel.png"),
  post: require("@/../assets/share/matchpoint-share-post.png"),
  message: require("@/../assets/share/matchpoint-share-message.png")
} as const;

/**
 * Enlace de descarga según la tienda del dispositivo que invita: App Store en
 * iOS y Google Play en Android. En web (y si no hay ficha de App Store
 * configurada) se cae a la web, que ya redirige a la tienda que toque.
 */
export function storeUrlForPlatform() {
  if (Platform.OS === "android") return PLAY_STORE_URL;
  if (Platform.OS === "ios") return APP_STORE_URL;
  return WEB_APP_URL;
}

export function buildAppInviteCopy(playerName: string) {
  return `${playerName} te invita a unirte a MP Tennis League App 🎾\n\nEncuentra gente de tu nivel, organiza partidos y descubre nuevos amigos dentro y fuera de la pista.`;
}

export function buildAppInviteMessage(playerName: string) {
  return `${buildAppInviteCopy(playerName)}\n\n${storeUrlForPlatform()}`;
}

export function buildLeagueInviteUrl(league: PrivateLeague) {
  return `${WEB_APP_URL}/private-league?id=${encodeURIComponent(league.id)}&code=${encodeURIComponent(league.inviteCode)}`;
}

export async function shareAppInvite(playerName: string) {
  const title = "Juega conmigo en MP Tennis League App";
  const url = storeUrlForPlatform();
  await Share.share(
    Platform.OS === "ios"
      ? { title, message: buildAppInviteCopy(playerName), url }
      : { title, message: `${buildAppInviteCopy(playerName)}\n\n${url}` }
  );
}

export async function shareMatchResultImage(uri: string, caption: string) {
  if (Platform.OS === "web" || !(await Sharing.isAvailableAsync())) {
    return Share.share({ title: "Resultado en MP Tennis League App", message: `${caption}\n\n${WEB_APP_URL}`, url: WEB_APP_URL });
  }
  await Sharing.shareAsync(uri, {
    mimeType: "image/png",
    dialogTitle: "Comparte tu resultado",
    UTI: "public.png"
  });
}

export async function shareLeagueInvite(league: PrivateLeague, playerName: string) {
  const url = buildLeagueInviteUrl(league);
  const title = `Únete a ${league.name}`;
  const message = `${playerName} te invita a jugar en su liga privada “${league.name}” de MP Tennis League App 🎾\n\nCódigo: ${league.inviteCode}`;
  await Share.share(
    Platform.OS === "ios"
      ? { title, message, url }
      : { title, message: `${message}\n${url}` }
  );
}

export async function shareCommunityBanner(playerName: string, format: CommunityShareFormat = "story") {
  if (Platform.OS === "web" || !(await Sharing.isAvailableAsync())) {
    return shareAppInvite(playerName);
  }
  const asset = Asset.fromModule(COMMUNITY_BANNERS[format]);
  await asset.downloadAsync();
  const uri = asset.localUri ?? asset.uri;
  await Sharing.shareAsync(uri, {
    mimeType: "image/png",
    dialogTitle: `${playerName} te invita a MP Tennis League App`,
    UTI: "public.png"
  });
}
