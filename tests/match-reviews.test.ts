import assert from "node:assert/strict";
import test from "node:test";
import { latestReviewPerAuthor, reviewTargets } from "../src/lib/reviews";
import type { MatchReview, MatchRoom } from "../src/types";

const skills = { consistency: 7, forehand: 7, backhand: 7, serve: 7, volley: 7 };

function review(authorId: string, targetId: string, createdAt: string): MatchReview {
  return {
    authorId,
    authorName: authorId,
    targetId,
    targetName: targetId,
    stars: 5,
    skillRatings: skills,
    createdAt
  };
}

test("cada autor cuenta una sola vez y conserva su valoración más reciente", () => {
  const reviews = latestReviewPerAuthor([
    review("friend", "player", "2026-01-01T10:00:00.000Z"),
    review("friend", "player", "2026-02-01T10:00:00.000Z"),
    review("other", "player", "2026-01-15T10:00:00.000Z")
  ]);

  assert.equal(reviews.length, 2);
  assert.equal(reviews.find((item) => item.authorId === "friend")?.createdAt, "2026-02-01T10:00:00.000Z");
});

test("en dobles se puede valorar por separado al compañero y a los dos rivales", () => {
  const room = {
    teamA: {
      side: "A",
      playerIds: ["me", "partner"],
      playerNames: ["Yo", "Compañero"],
      captainId: "me"
    },
    teamB: {
      side: "B",
      playerIds: ["rival-1", "rival-2"],
      playerNames: ["Rival uno", "Rival dos"],
      captainId: "rival-1"
    }
  } as MatchRoom;

  assert.deepEqual(reviewTargets(room, "me").map((target) => target.id), ["partner", "rival-1", "rival-2"]);
});
