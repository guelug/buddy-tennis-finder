import { Platform, Share } from "react-native";
import { Asset } from "expo-asset";
import * as Sharing from "expo-sharing";
import type { PrivateLeague } from "@/types";

export const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.matchpoint.clubs";
export const WEB_APP_URL = process.env.EXPO_PUBLIC_APP_URL || "https://tenisbuddy-app.web.app";

export function buildAppInviteMessage(playerName: string) {
  return `${playerName} te invita a unirte a MatchPoint Tennis 🎾\n\nEncuentra gente de tu nivel, organiza partidos y descubre nuevos amigos dentro y fuera de la pista.\n\n${PLAY_STORE_URL}`;
}

export function buildLeagueInviteUrl(league: PrivateLeague) {
  return `${WEB_APP_URL}/private-league?id=${encodeURIComponent(league.id)}&code=${encodeURIComponent(league.inviteCode)}`;
}

export async function shareAppInvite(playerName: string) {
  await Share.share({
    title: "Juega conmigo en MatchPoint Tennis",
    message: buildAppInviteMessage(playerName),
    url: PLAY_STORE_URL
  });
}

export async function shareLeagueInvite(league: PrivateLeague, playerName: string) {
  const url = buildLeagueInviteUrl(league);
  await Share.share({
    title: `Únete a ${league.name}`,
    message: `${playerName} te invita a jugar en su liga privada “${league.name}” de MatchPoint Tennis 🎾\n\nCódigo: ${league.inviteCode}\n${url}`,
    url
  });
}

export async function shareCommunityBanner(playerName: string) {
  if (Platform.OS === "web" || !(await Sharing.isAvailableAsync())) {
    return shareAppInvite(playerName);
  }
  const asset = Asset.fromModule(require("@/../assets/share/matchpoint-share-banner.png"));
  await asset.downloadAsync();
  const uri = asset.localUri ?? asset.uri;
  await Sharing.shareAsync(uri, {
    mimeType: "image/png",
    dialogTitle: `${playerName} te invita a MatchPoint Tennis`,
    UTI: "public.png"
  });
}
