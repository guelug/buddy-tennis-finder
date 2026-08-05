/**
 * Auto-match para partidos casuales.
 *
 * Regla de producto: cuando alguien publica que busca rival y YA hay otra
 * persona buscando en la misma ciudad con nivel compatible, se emparejan
 * automáticamente. El aviso le llega al que estaba PRIMERO (quien publicó
 * antes), para que sea quien proponga la reserva. Ambos siguen apareciendo
 * como "buscando partido" para poder ojearse entre sí y con otros.
 *
 * Lógica pura y testeable: decide el emparejamiento sin tocar Firestore.
 */
import { isLevelCompatible } from "@/lib/matching";
import type { SkillLevel } from "@/types";

export type TeamSeeker = {
  id: string;
  name: string;
  level: SkillLevel;
  city: string;
  clubIds: string[];
  /** Momento en el que quedó marcado como "buscando" (ISO). */
  seekingSince: string;
};

/**
 * Devuelve el jugador con el que se empareja automáticamente a `seeker`,
 * o null si nadie cumple los requisitos.
 *
 * Criterios, en orden:
 *  1. Misma ciudad (el ranking y los partidos son por ciudad).
 *  2. Nivel compatible (mismo nivel o adyacente — ver isLevelCompatible).
 *  3. Que no sea el propio buscador.
 *  4. El más antiguo primero (quien llevaba más tiempo buscando).
 *  5. Desempate: quien comparte club con el buscador gana.
 */
export function findAutoMatch(
  seeker: TeamSeeker,
  seekers: TeamSeeker[]
): TeamSeeker | null {
  const eligible = seekers
    .filter((candidate) => candidate.id !== seeker.id)
    .filter((candidate) => candidate.city === seeker.city)
    .filter((candidate) => isLevelCompatible(candidate.level, seeker.level))
    .sort((a, b) => {
      const byTime = a.seekingSince.localeCompare(b.seekingSince);
      if (byTime !== 0) return byTime;
      const aSharesClub = a.clubIds.some((clubId) => seeker.clubIds.includes(clubId));
      const bSharesClub = b.clubIds.some((clubId) => seeker.clubIds.includes(clubId));
      if (aSharesClub !== bSharesClub) return aSharesClub ? -1 : 1;
      return a.name.localeCompare(b.name);
    });

  return eligible[0] ?? null;
}

/**
 * Ordena la lista de "buscando partido" para mostrarla en Matches: primero
 * quien comparte club, después los demás por antigüedad (el más antiguo
 * arriba, coherente con quién recibe el auto-match).
 */
export function rankTeamSeekers(
  viewer: TeamSeeker,
  seekers: TeamSeeker[]
): TeamSeeker[] {
  return seekers
    .filter((candidate) => candidate.id !== viewer.id)
    .filter((candidate) => candidate.city === viewer.city)
    .sort((a, b) => {
      const aSharesClub = a.clubIds.some((clubId) => viewer.clubIds.includes(clubId));
      const bSharesClub = b.clubIds.some((clubId) => viewer.clubIds.includes(clubId));
      if (aSharesClub !== bSharesClub) return aSharesClub ? -1 : 1;
      return a.seekingSince.localeCompare(b.seekingSince);
    });
}
