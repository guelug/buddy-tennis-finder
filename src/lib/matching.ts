import { MatchCandidate, MatchProposal, Player, SearchPreferences, SkillLevel } from "../types";

const levelValue: Record<SkillLevel, number> = {
  novato: 1,
  d: 2,
  c: 3,
  b: 4,
  a: 5
};

/** Dos niveles son compatibles si son iguales o adyacentes (±1). */
export function isLevelCompatible(a: SkillLevel, b: SkillLevel): boolean {
  return Math.abs(levelValue[a] - levelValue[b]) <= 1;
}

export function rankCandidates(
  currentPlayer: Player,
  allPlayers: Player[],
  preferences: SearchPreferences
): MatchCandidate[] {
  return allPlayers
    // Los perfiles de muestra sirven únicamente para rankings y bloques
    // editoriales. Nunca son rivales buscables ni candidatos interactivos.
    .filter((player) => player.id !== currentPlayer.id && player.isDemo !== true)
    .map((player) => {
      const sharedSlots = findSharedSlots(currentPlayer, player);
      const sharedFormats = player.preferredFormats.filter((format) =>
        preferences.formats.includes(format)
      );
      const levelGap = Math.abs(levelValue[currentPlayer.level] - levelValue[player.level]);
      const sharedClubs = player.clubIds.filter((id) => currentPlayer.clubIds.includes(id));

      let score = 100;
      score -= levelGap * 12;
      score += sharedSlots.length * 11;
      score += sharedFormats.length * 8;
      score += sharedClubs.length > 0 ? 16 : 0;
      score += player.responseRate / 10;
      score += player.rating * 2;

      const reasons = [
        sharedClubs.length > 0
          ? `comparten ${sharedClubs.length > 1 ? `${sharedClubs.length} clubes` : "club"}`
          : "otros clubes",
        sharedSlots.length > 0 ? "horarios compatibles" : "sin horario exacto compartido",
        levelGap <= 1 ? "nivel cercano" : "nivel distinto",
        sharedFormats.length > 0 ? `${sharedFormats.join(", ")}` : "formato flexible"
      ];

      return {
        player,
        score: Math.max(0, Math.round(score)),
        sharedSlots,
        reasons
      };
    })
    .filter(({ player }) => preferences.level === "any" || player.level === preferences.level)
    .filter(({ player }) => player.age >= preferences.ageMin && player.age <= preferences.ageMax)
    .filter(
      (candidate) => !preferences.requireSharedAvailability || candidate.sharedSlots.length > 0
    )
    .sort((a, b) => {
      // Primero banda de compatibilidad y, dentro de una diferencia pequeña,
      // gana quien comparte club con el jugador actual.
      const bandA = Math.floor(compatibilityPct(a.score) / 5);
      const bandB = Math.floor(compatibilityPct(b.score) / 5);
      if (bandA !== bandB) return bandB - bandA;
      const aSharedClub = a.player.clubIds.some((clubId) =>
        currentPlayer.clubIds.includes(clubId)
      );
      const bSharedClub = b.player.clubIds.some((clubId) =>
        currentPlayer.clubIds.includes(clubId)
      );
      if (aSharedClub !== bSharedClub) return aSharedClub ? -1 : 1;
      return b.score - a.score;
    });
}

/**
 * De todas las propuestas existentes, devuelve las que son ABIERTAS (nadie las
 * ha aceptado aún), no son del propio jugador y su nivel es compatible con el
 * suyo. Ordena primero las de sus clubes y luego el resto.
 */
export function rankOpenProposals(
  currentPlayer: Player,
  proposals: MatchProposal[],
  clubs: { id: string; name: string }[]
): Array<{ proposal: MatchProposal; clubName: string; sharedClub: boolean }> {
  const open = proposals.filter(
    (p) =>
      p.acceptedByPlayerId === null &&
      p.status === "proposed" &&
      new Date(p.startsAt).getTime() > Date.now() &&
      p.fromPlayerId !== currentPlayer.id &&
      (p.acceptedLevels?.length
        ? p.acceptedLevels.includes(currentPlayer.level)
        : isLevelCompatible(p.division, currentPlayer.level))
  );

  return open
    .map((proposal) => {
      const sharedClub = currentPlayer.clubIds.includes(proposal.clubId);
      const clubName = clubs.find((c) => c.id === proposal.clubId)?.name ?? "Club";
      return { proposal, clubName, sharedClub };
    })
    .sort((a, b) => {
      if (a.sharedClub && !b.sharedClub) return -1;
      if (!a.sharedClub && b.sharedClub) return 1;
      return a.proposal.proposedAt > b.proposal.proposedAt ? -1 : 1;
    });
}

function findSharedSlots(a: Player, b: Player) {
  const slots: string[] = [];

  for (const aSlot of a.availability) {
    const bSlot = b.availability.find((slot) => slot.day === aSlot.day);
    if (!bSlot) {
      continue;
    }

    for (const aRange of aSlot.ranges) {
      for (const bRange of bSlot.ranges) {
        const overlap = overlapTimeRanges(aRange, bRange);
        if (overlap) {
          slots.push(`${aSlot.day} ${overlap}`);
        }
      }
    }
  }

  return Array.from(new Set(slots));
}

function overlapTimeRanges(aRange: string, bRange: string) {
  const a = parseTimeRange(aRange);
  const b = parseTimeRange(bRange);

  if (!a || !b) {
    return null;
  }

  const start = Math.max(a.start, b.start);
  const end = Math.min(a.end, b.end);

  if (end <= start) {
    return null;
  }

  return `${formatMinutes(start)}-${formatMinutes(end)}`;
}

function parseTimeRange(range: string) {
  const [start, end] = range.split("-").map(parseTime);

  if (start === null || end === null) {
    return null;
  }

  return { start, end };
}

function parseTime(value: string) {
  const [hours, minutes] = value.split(":").map(Number);

  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) {
    return null;
  }

  return hours * 60 + minutes;
}

function formatMinutes(value: number) {
  const hours = Math.floor(value / 60);
  const minutes = value % 60;

  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
}

export function levelLabel(level: SkillLevel) {
  const labels: Record<SkillLevel, string> = {
    novato: "Novato",
    d: "D",
    c: "C",
    b: "B",
    a: "A"
  };

  return labels[level];
}

/**
 * Convierte el score de matching (índice abierto, ~0-180) a un porcentaje de
 * compatibilidad 20-99 para la UI del concepto (anillos "86%").
 */
export function compatibilityPct(score: number) {
  return Math.max(20, Math.min(99, Math.round(score * 0.6)));
}
