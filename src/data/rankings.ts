import { clubs, players } from "./seed";
import { Club, Division, Player, RankTier, RankingEntry, ValidatedRankingResult } from "../types";

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
      city: player.city,
      country: player.country,
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
export function buildProvisionalRankings(
  sourcePlayers: Player[],
  sourceClubs: Club[],
  validatedResults: ValidatedRankingResult[] = []
) {
  const result = {} as Record<Division, RankingEntry[]>;
  for (const division of Object.keys(DIVISION_LABELS) as Division[]) {
    const records = new Map<string, { wins: number; losses: number }>();
    for (const match of validatedResults.filter((item) => item.division === division)) {
      for (const playerId of [match.playerAId, match.playerBId]) {
        const record = records.get(playerId) ?? { wins: 0, losses: 0 };
        if (match.winnerId === playerId) record.wins += 1;
        else record.losses += 1;
        records.set(playerId, record);
      }
    }
    const sorted = sourcePlayers
      .filter((player) => player.profileComplete && player.level === division && player.isDemo !== true)
      .sort((a, b) => {
        const aRecord = records.get(a.id) ?? { wins: 0, losses: 0 };
        const bRecord = records.get(b.id) ?? { wins: 0, losses: 0 };
        const aPoints = aRecord.wins * 100 + aRecord.losses * 25;
        const bPoints = bRecord.wins * 100 + bRecord.losses * 25;
        return bPoints - aPoints || bRecord.wins - aRecord.wins || a.name.localeCompare(b.name);
      });
    result[division] = sorted.map((player, index) => {
      const rank = index + 1;
      const club = sourceClubs.find((item) => player.clubIds.includes(item.id));
      const record = records.get(player.id) ?? { wins: 0, losses: 0 };
      return {
        rank,
        playerId: player.id,
        playerName: player.name,
        division,
        tier: tierForRank(rank),
        points: record.wins * 100 + record.losses * 25,
        wins: record.wins,
        losses: record.losses,
        streak: 0,
        clubName: club?.name,
        city: player.city,
        country: player.country,
        isDemo: player.isDemo === true
      };
    });
  }
  return result;
}

/**
 * Filtra un ranking a la región del jugador y renumera las posiciones para que
 * la tabla regional sea 1..N y no muestre huecos del ranking global.
 */
export function scopeRankingToArea(entries: RankingEntry[], city?: string, country?: string): RankingEntry[] {
  const normalize = (value: string | undefined) =>
    (value ?? "").trim().toLocaleLowerCase("es").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const targetCity = normalize(city);
  const targetCountry = normalize(country);
  if (!targetCity && !targetCountry) return entries;
  return entries
    .filter((entry) => {
      const entryCity = normalize(entry.city);
      // Un perfil sin ciudad se agrupa por país; si tampoco tiene país, se
      // queda fuera del regional pero sigue apareciendo en el global.
      if (!entryCity || !targetCity) return Boolean(targetCountry) && normalize(entry.country) === targetCountry;
      return entryCity === targetCity;
    })
    .map((entry, index) => ({ ...entry, rank: index + 1 }));
}
