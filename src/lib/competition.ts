import { rankingsByDivision, allRankings } from "@/data/rankings";
import { playedMatches } from "@/data/match-history";
import { Division, PlayedMatch, RankingEntry } from "@/types";

export function getRankings(division?: Division): RankingEntry[] {
  if (division) return rankingsByDivision[division] ?? [];
  return [...allRankings].sort((a, b) => b.points - a.points);
}

export function getPlayedMatches(playerId?: string): PlayedMatch[] {
  const sorted = [...playedMatches].sort((a, b) => (a.playedAt > b.playedAt ? -1 : 1));
  if (!playerId) return sorted;
  return sorted.filter((m) => m.playerAId === playerId || m.playerBId === playerId);
}

export function getPlayerRanking(playerId: string, division: Division): RankingEntry | undefined {
  return rankingsByDivision[division]?.find((e) => e.playerId === playerId);
}