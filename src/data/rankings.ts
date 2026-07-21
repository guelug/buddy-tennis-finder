import { clubs, players } from "./seed";
import { Club, Division, Player, RankTier, RankingEntry } from "../types";

export const DIVISION_LABELS: Record<Division, string> = {
  novato: "Novato",
  d: "D",
  c: "C",
  b: "B",
  a: "A"
};

export const DIVISION_META: Record<Division, { circuit: string; number: string; motto: string; proof: string; accent: string }> = {
  novato: { circuit: "QUALIFYING", number: "Q", motto: "Construye tu juego", proof: "Fundamentos · primeros partidos", accent: "#A8CF63" },
  d: { circuit: "FUTURES", number: "D", motto: "Empieza a competir", proof: "Regularidad · lectura de pista", accent: "#70C9A7" },
  c: { circuit: "CHALLENGER", number: "C", motto: "Consolida tu identidad", proof: "Patrones · presión competitiva", accent: "#C6F135" },
  b: { circuit: "MASTERS", number: "B", motto: "Domina cada patrón", proof: "Táctica · ritmo alto", accent: "#F5C542" },
  a: { circuit: "TOUR ELITE", number: "A", motto: "Compite al máximo nivel", proof: "Precisión · mentalidad ganadora", accent: "#FF7B62" }
};

export const TIER_META: Record<RankTier, { label: string; color: string; glow: string; icon: string }> = {
  bronce: { label: "Bronce", color: "#B87333", glow: "rgba(184,115,51,0.35)", icon: "◆" },
  plata: { label: "Plata", color: "#8A9BA8", glow: "rgba(138,155,168,0.35)", icon: "◆" },
  oro: { label: "Oro", color: "#E0A934", glow: "rgba(224,169,52,0.45)", icon: "★" },
  platino: { label: "Platino", color: "#3FB6A8", glow: "rgba(63,182,168,0.4)", icon: "★" },
  elite: { label: "Elite", color: "#0B5E3A", glow: "rgba(11,94,58,0.5)", icon: "♛" }
};

function tierForRank(rank: number): RankTier {
  if (rank === 1) return "elite";
  if (rank <= 3) return "platino";
  if (rank <= 6) return "oro";
  if (rank <= 10) return "plata";
  return "bronce";
}

function buildDivisionRankings(division: Division): RankingEntry[] {
  const pool = players.filter((p) => p.level === division || (division === "c" && p.id === "me"));
  const sorted = [...pool].sort((a, b) => b.rating - a.rating || b.responseRate - a.responseRate);

  return sorted.map((player, index) => {
    const rank = index + 1;
    const club = clubs.find((c) => player.clubIds.includes(c.id));
    const basePoints = Math.round(player.rating * 220 + player.responseRate * 2);
    return {
      rank,
      playerId: player.id,
      playerName: player.name,
      division,
      tier: tierForRank(rank),
      points: basePoints - index * 12,
      wins: Math.max(3, 18 - index * 2),
      losses: Math.min(12, 2 + index),
      streak: Math.max(0, 5 - index),
      clubName: club?.name,
      isDemo: player.id !== "me"
    };
  });
}

export const rankingsByDivision: Record<Division, RankingEntry[]> = {
  novato: buildDivisionRankings("novato"),
  d: buildDivisionRankings("d"),
  c: buildDivisionRankings("c"),
  b: buildDivisionRankings("b"),
  a: buildDivisionRankings("a")
};

export const allRankings = Object.values(rankingsByDivision).flat();

/**
 * Ranking provisional de producción. Solo usa señales reales ya disponibles
 * en el perfil; victorias y rachas permanecen a cero hasta que exista el
 * backend de resultados validados.
 */
export function buildProvisionalRankings(sourcePlayers: Player[], sourceClubs: Club[]) {
  const result = {} as Record<Division, RankingEntry[]>;
  for (const division of Object.keys(DIVISION_LABELS) as Division[]) {
    const sorted = sourcePlayers
      .filter((player) => player.profileComplete && player.level === division)
      .sort((a, b) => b.rating - a.rating || b.responseRate - a.responseRate || a.name.localeCompare(b.name));
    result[division] = sorted.map((player, index) => {
      const rank = index + 1;
      const club = sourceClubs.find((item) => player.clubIds.includes(item.id));
      return {
        rank,
        playerId: player.id,
        playerName: player.name,
        division,
        tier: tierForRank(rank),
        points: Math.round(player.rating * 100 + player.responseRate * 2),
        wins: 0,
        losses: 0,
        streak: 0,
        clubName: club?.name,
        isDemo: player.isDemo === true
      };
    });
  }
  return result;
}
