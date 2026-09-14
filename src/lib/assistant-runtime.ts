import type { MatchRoom } from "../types";

/** Recheck on the next request: the user can enable AI or finish downloading it. */
export function deduplicateInFlight<T>(read: () => Promise<T>): () => Promise<T> {
  let pending: Promise<T> | null = null;
  return () => {
    if (!pending) {
      pending = Promise.resolve().then(read).finally(() => { pending = null; });
    }
    return pending;
  };
}

export function assistantMatchSummary(rooms: MatchRoom[], playerId: string) {
  const results = rooms.filter((room) => room.result &&
    (room.teamA.playerIds.includes(playerId) || room.teamB.playerIds.includes(playerId)));
  let wins = 0;
  let losses = 0;
  for (const room of results) {
    if (room.status !== "validated") continue;
    const side = room.teamA.playerIds.includes(playerId) ? "A" : "B";
    if (room.result?.winner === side) wins += 1;
    else if (room.result?.winner === "A" || room.result?.winner === "B") losses += 1;
  }
  return {
    wins,
    losses,
    recentRooms: results.sort((a, b) => b.playedAt.localeCompare(a.playedAt)).slice(0, 5)
  };
}
