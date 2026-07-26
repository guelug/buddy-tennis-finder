import { Division } from "@/types";

export type TeamStanding = {
  id: string;
  name: string;
  members: [string, string];
  division: Division;
  points: number;
  wins: number;
  losses: number;
  setsFor: number;
  setsAgainst: number;
};

export type ClubLeague = {
  id: string;
  name: string;
  division: Division;
  format: "individual" | "doubles";
  status: "open" | "full" | "playing" | "closed";
  participants: number;
  capacity: number;
  /** Perfiles de muestra para enriquecer la tarjeta; nunca cuentan como inscritos. */
  demoParticipants?: number;
  season: string;
};

export type IndividualTournament = {
  id: string;
  name: string;
  division: Division;
  status: "registration" | "draw" | "playing" | "finished";
  entrants: number;
  capacity: number;
  /** Perfiles de muestra para la preview; nunca cuentan como inscritos. */
  demoEntrants?: number;
  round: string;
};

export const teamStandings: TeamStanding[] = [
  { id: "t1", name: "Top Spin", members: ["Ana Morales", "Carlos Rivera"], division: "c", points: 1280, wins: 9, losses: 2, setsFor: 20, setsAgainst: 8 },
  { id: "t2", name: "Red Crushers", members: ["María F. López", "Diego Castillo"], division: "c", points: 1195, wins: 8, losses: 3, setsFor: 18, setsAgainst: 10 },
  { id: "t3", name: "Match Makers", members: ["Sofía Arévalo", "Carlos Rivera"], division: "novato", points: 980, wins: 6, losses: 4, setsFor: 14, setsAgainst: 11 },
  { id: "t4", name: "Baseline Club", members: ["Ana Morales", "Diego Castillo"], division: "b", points: 910, wins: 5, losses: 5, setsFor: 12, setsAgainst: 12 }
];

export const initialLeagues: ClubLeague[] = [
  { id: "l-novato-individual", name: "Liga Novato · Individual", division: "novato", format: "individual", status: "open", participants: 0, capacity: 16, demoParticipants: 8, season: "2026 · Apertura" },
  { id: "l-novato-doubles", name: "Liga Novato · Dobles", division: "novato", format: "doubles", status: "open", participants: 0, capacity: 8, demoParticipants: 4, season: "2026 · Apertura" },
  { id: "l-d-individual", name: "Liga D · Individual", division: "d", format: "individual", status: "open", participants: 0, capacity: 16, demoParticipants: 9, season: "2026 · Apertura" },
  { id: "l-d-doubles", name: "Liga D · Dobles", division: "d", format: "doubles", status: "open", participants: 0, capacity: 8, demoParticipants: 4, season: "2026 · Apertura" },
  { id: "l-c-individual", name: "Liga C · Individual", division: "c", format: "individual", status: "open", participants: 0, capacity: 24, demoParticipants: 12, season: "2026 · Apertura" },
  { id: "l-c-doubles", name: "Liga C · Dobles", division: "c", format: "doubles", status: "open", participants: 0, capacity: 12, demoParticipants: 6, season: "2026 · Apertura" },
  { id: "l-b-individual", name: "Liga B · Individual", division: "b", format: "individual", status: "open", participants: 0, capacity: 16, demoParticipants: 8, season: "2026 · Apertura" },
  { id: "l-b-doubles", name: "Liga B · Dobles", division: "b", format: "doubles", status: "open", participants: 0, capacity: 8, demoParticipants: 4, season: "2026 · Apertura" },
  { id: "l-a-individual", name: "Liga A · Individual", division: "a", format: "individual", status: "open", participants: 0, capacity: 16, demoParticipants: 10, season: "2026 · Apertura" },
  { id: "l-a-doubles", name: "Liga A · Dobles", division: "a", format: "doubles", status: "open", participants: 0, capacity: 8, demoParticipants: 4, season: "2026 · Apertura" }
];

/**
 * Ciudades con liga pública propia. Las ligas son POR CIUDAD: no tiene sentido
 * que alguien de Barcelona compita en la misma tabla que alguien de Ciudad de
 * Guatemala, porque nunca van a poder jugar el partido.
 */
export const LEAGUE_CITIES: Record<string, string> = {
  "Ciudad de Guatemala": "guatemala",
  "San Salvador": "san-salvador",
  Barcelona: "barcelona"
};

/** Sufijo estable de ciudad para construir el id de liga. */
export function citySlug(city: string | undefined | null): string | null {
  if (!city) return null;
  return LEAGUE_CITIES[city] ?? null;
}

/**
 * Liga pública oficial de cada rango y ciudad: la de formato individual.
 * Siempre abierta y gratuita — cualquier jugador puede inscribirse en la de SU
 * rango y SU ciudad. Las ligas privadas (crear/gestionar) serán de pago.
 *
 * Si la ciudad todavía no tiene liga propia se devuelve la liga histórica sin
 * sufijo, que es la que ya tienen guardada los perfiles creados antes de
 * separar por ciudad.
 */
export function publicLeagueForDivision(division: Division, city?: string | null): ClubLeague {
  const base = initialLeagues.find((league) => league.division === division && league.format === "individual")
    ?? initialLeagues.find((league) => league.division === division)!;
  const slug = citySlug(city);
  if (!slug) return base;
  return { ...base, id: `${base.id}-${slug}`, name: `${base.name} · ${city}` };
}

/**
 * Ids que se aceptan como "estar inscrito" en la liga de un rango y ciudad:
 * el id con ciudad y el id histórico sin ciudad. Así nadie pierde su
 * inscripción al desplegar la separación regional.
 */
export function publicLeagueIdsFor(division: Division, city?: string | null): string[] {
  const base = publicLeagueForDivision(division, null);
  const scoped = publicLeagueForDivision(division, city);
  return scoped.id === base.id ? [base.id] : [scoped.id, base.id];
}

/**
 * Resuelve un id de liga pública (con o sin sufijo de ciudad) al objeto liga,
 * devolviendo el nombre ya localizado a la ciudad correspondiente.
 */
export function findPublicLeague(id: string | undefined): ClubLeague | null {
  if (!id) return null;
  const exact = initialLeagues.find((league) => league.id === id);
  if (exact) return exact;
  for (const [city, slug] of Object.entries(LEAGUE_CITIES)) {
    const suffix = `-${slug}`;
    if (!id.endsWith(suffix)) continue;
    const base = initialLeagues.find((league) => league.id === id.slice(0, -suffix.length));
    if (base) return { ...base, id, name: `${base.name} · ${city}` };
  }
  return null;
}

/** Todos los ids de liga pública válidos — se refleja en firestore.rules. */
export function allPublicLeagueIds(): string[] {
  const ids: string[] = [];
  for (const league of initialLeagues) {
    if (league.format !== "individual") continue;
    ids.push(league.id);
    for (const slug of Object.values(LEAGUE_CITIES)) ids.push(`${league.id}-${slug}`);
  }
  return ids;
}

export const tournaments: IndividualTournament[] = [
  { id: "tr-novato", name: "Open MatchPoint · Novato", division: "novato", status: "registration", entrants: 0, capacity: 16, demoEntrants: 8, round: "Inscripción abierta" },
  { id: "tr-d", name: "Open MatchPoint · D", division: "d", status: "registration", entrants: 0, capacity: 24, demoEntrants: 12, round: "Inscripción abierta" },
  { id: "tr-c", name: "Open MatchPoint · C", division: "c", status: "registration", entrants: 0, capacity: 32, demoEntrants: 18, round: "Inscripción abierta" },
  { id: "tr-b", name: "Open MatchPoint · B", division: "b", status: "registration", entrants: 0, capacity: 24, demoEntrants: 12, round: "Inscripción abierta" },
  { id: "tr-a", name: "Open MatchPoint · A", division: "a", status: "registration", entrants: 0, capacity: 16, demoEntrants: 8, round: "Inscripción abierta" }
];
