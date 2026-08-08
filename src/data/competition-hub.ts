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
/**
 * Área de liga de cada ciudad. Varias ciudades comparten área a propósito: la
 * liga pública es por COMUNIDAD, no por municipio. Si cada pueblo tuviera la
 * suya, quien vive en Pallejà competiría solo contra su pueblo y la liga
 * nacería con un inscrito.
 *
 * El `slug` de Catalunya sigue siendo "barcelona" para no invalidar las
 * inscripciones ya guardadas ni los ids que replica firestore.rules; lo que
 * cambia es la etiqueta que se muestra.
 */
export const LEAGUE_AREAS: Record<string, { slug: string; label: string }> = {
  "Ciudad de Guatemala": { slug: "guatemala", label: "Ciudad de Guatemala" },
  "San Salvador": { slug: "san-salvador", label: "San Salvador" },
  Barcelona: { slug: "barcelona", label: "Catalunya" },
  "Pallejà": { slug: "barcelona", label: "Catalunya" },
  Castelldefels: { slug: "barcelona", label: "Catalunya" },
  Formigal: { slug: "aragon", label: "Aragón" }
};

/** Slugs únicos: varias ciudades comparten uno. */
export const LEAGUE_SLUGS: string[] = Array.from(
  new Set(Object.values(LEAGUE_AREAS).map((area) => area.slug))
);

/** Sufijo estable de área para construir el id de liga. */
export function citySlug(city: string | undefined | null): string | null {
  if (!city) return null;
  return LEAGUE_AREAS[city]?.slug ?? null;
}

/** Etiqueta del área a la que pertenece una ciudad. */
export function areaLabel(city: string | undefined | null): string | null {
  if (!city) return null;
  return LEAGUE_AREAS[city]?.label ?? null;
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
  return { ...base, id: `${base.id}-${slug}`, name: `${base.name} · ${areaLabel(city) ?? city}` };
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
  for (const [city, area] of Object.entries(LEAGUE_AREAS)) {
    const suffix = `-${area.slug}`;
    if (!id.endsWith(suffix)) continue;
    const base = initialLeagues.find((league) => league.id === id.slice(0, -suffix.length));
    if (base) return { ...base, id, name: `${base.name} · ${area.label ?? city}` };
  }
  return null;
}

/** Todos los ids de liga pública válidos — se refleja en firestore.rules. */
export function allPublicLeagueIds(): string[] {
  const ids: string[] = [];
  for (const league of initialLeagues) {
    if (league.format !== "individual") continue;
    ids.push(league.id);
    for (const slug of LEAGUE_SLUGS) ids.push(`${league.id}-${slug}`);
  }
  return ids;
}

export const tournaments: IndividualTournament[] = [
  { id: "tr-novato", name: "Open MP · Novato", division: "novato", status: "registration", entrants: 0, capacity: 16, demoEntrants: 8, round: "Inscripción abierta" },
  { id: "tr-d", name: "Open MP · D", division: "d", status: "registration", entrants: 0, capacity: 24, demoEntrants: 12, round: "Inscripción abierta" },
  { id: "tr-c", name: "Open MP · C", division: "c", status: "registration", entrants: 0, capacity: 32, demoEntrants: 18, round: "Inscripción abierta" },
  { id: "tr-b", name: "Open MP · B", division: "b", status: "registration", entrants: 0, capacity: 24, demoEntrants: 12, round: "Inscripción abierta" },
  { id: "tr-a", name: "Open MP · A", division: "a", status: "registration", entrants: 0, capacity: 16, demoEntrants: 8, round: "Inscripción abierta" }
];
