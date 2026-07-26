import type { MatchReview, MatchRoom } from "@/types";

export function reviewTargets(room: MatchRoom, authorId: string) {
  return [
    ...room.teamA.playerIds.map((id, index) => ({ id, name: room.teamA.playerNames[index] })),
    ...room.teamB.playerIds.map((id, index) => ({ id, name: room.teamB.playerNames[index] }))
  ].filter((player) => player.id !== authorId);
}

/** Una persona cuenta una sola vez en el promedio: conserva su opinión más reciente. */
export function latestReviewPerAuthor(reviews: MatchReview[]): MatchReview[] {
  const sorted = [...reviews].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  const authors = new Set<string>();
  return sorted.filter((review) => {
    if (authors.has(review.authorId)) return false;
    authors.add(review.authorId);
    return true;
  });
}
