import { clubs, currentPlayer, players as seedPlayers } from "../data/seed";
import { rankCandidates } from "./matching";
import { MatchProposal, SearchPreferences } from "../types";

const defaultPreferences: SearchPreferences = {
  level: "any",
  formats: ["singles", "mixed"],
  ageMin: 18,
  ageMax: 65,
  requireSharedAvailability: true
};

const players = seedPlayers.map((player) => player.id === currentPlayer.id
  ? { ...player, profileComplete: true }
  : { ...player, isDemo: true, profileComplete: true, responseRate: 0 });

// El modo local también respeta la regla de producto: nunca inventamos
// partidos abiertos. Solo aparecen los que la persona publique en la sesión.
let localProposals: MatchProposal[] = [];

export async function getHomeData(preferences = defaultPreferences) {
  return {
    currentPlayer,
    players,
    clubs,
    candidates: rankCandidates(currentPlayer, players, preferences),
    proposals: localProposals
  };
}

export async function createProposal(
  input: Omit<MatchProposal, "id" | "fromPlayerId" | "proposedAt" | "status" | "acceptedByPlayerId">
) {
  const proposal: MatchProposal = {
    ...input,
    acceptedByPlayerId: null,
    id: `m-${Date.now()}`,
    fromPlayerId: currentPlayer.id,
    proposedAt: new Date().toISOString(),
    status: "proposed"
  };

  localProposals = [proposal, ...localProposals];
  return proposal;
}

export async function updateProposalStatus(id: string, status: MatchProposal["status"]) {
  const current = localProposals.find((proposal) => proposal.id === id);
  if (!current) throw new Error("La propuesta ya no existe.");
  if (status === "accepted") {
    if (current.fromPlayerId === currentPlayer.id) throw new Error("No puedes aceptar tu propia propuesta.");
    if (current.status !== "proposed" || current.acceptedByPlayerId !== null) {
      throw new Error("Otro jugador ya aceptó esta reserva.");
    }
  } else if (status === "declined" && current.fromPlayerId !== currentPlayer.id) {
    throw new Error("Solo quien publicó la reserva puede cancelarla.");
  } else if (status === "proposed" && current.acceptedByPlayerId !== currentPlayer.id) {
    throw new Error("Solo quien aceptó el partido puede liberar la plaza.");
  }
  localProposals = localProposals.map((proposal) => {
    if (proposal.id !== id) return proposal;
    const next: MatchProposal = { ...proposal, status };
    if (status === "accepted") next.acceptedByPlayerId = currentPlayer.id;
    else if (status === "proposed") next.acceptedByPlayerId = null;
    return next;
  });
  return localProposals.find((proposal) => proposal.id === id);
}
