import { PlayedMatch } from "../types";

/** Partidos ya jugados — historial para rivales anteriores. */
export const playedMatches: PlayedMatch[] = [
  {
    id: "h-1",
    playerAId: "me",
    playerBId: "p-1",
    playerAName: "Ana Morales",
    playerBName: "Carlos Rivera",
    winnerId: "me",
    score: "6-4, 7-5",
    clubId: "club-hercules",
    playedAt: "2026-05-28T23:00:00.000Z",
    format: "singles",
    division: "c"
  },
  {
    id: "h-2",
    playerAId: "p-2",
    playerBId: "me",
    playerAName: "María Fernanda López",
    playerBName: "Ana Morales",
    winnerId: "p-2",
    score: "6-2, 6-3",
    clubId: "club-sporta",
    playedAt: "2026-05-15T01:00:00.000Z",
    format: "singles",
    division: "b"
  },
  {
    id: "h-3",
    playerAId: "me",
    playerBId: "p-3",
    playerAName: "Ana Morales",
    playerBName: "Diego Castillo",
    winnerId: "me",
    score: "7-6, 6-4",
    clubId: "club-antigua",
    playedAt: "2026-04-20T15:00:00.000Z",
    format: "mixed",
    division: "c"
  },
  {
    id: "h-4",
    playerAId: "p-4",
    playerBId: "p-1",
    playerAName: "Sofía Arévalo",
    playerBName: "Carlos Rivera",
    winnerId: "p-1",
    score: "6-1, 6-2",
    clubId: "club-alemán",
    playedAt: "2026-05-10T22:00:00.000Z",
    format: "singles",
    division: "novato"
  },
  {
    id: "h-5",
    playerAId: "p-2",
    playerBId: "p-3",
    playerAName: "María Fernanda López",
    playerBName: "Diego Castillo",
    winnerId: "p-2",
    score: "6-3, 6-4",
    clubId: "club-sporta",
    playedAt: "2026-05-22T01:30:00.000Z",
    format: "doubles",
    division: "b"
  }
];
