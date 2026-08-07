/**
 * Golden set test for the rank engine.
 *
 * computeScore takes now as a parameter rather than reading the
 * clock itself, so this is a pure, deterministic test with no
 * Firestore and no emulator. Fixture restaurants carry votes at
 * fixed, known ages spanning the decay curve, and the assertion is
 * the exact resulting order, not that scores are positive or that
 * more votes rank higher. On failure, Jest's array diff shows
 * expected order versus actual order directly, since a reordering
 * regression is exactly what this guards against.
 */

import {computeScore, assignRanks, DEFAULT_HALF_LIFE_DAYS} from "./rank_engine";
import type {VoteRecord, ScoredRestaurant} from "./rank_engine";

describe("Rank engine golden set", () => {
  const now = new Date("2026-06-11T12:00:00Z");
  const msPerDay = 24 * 60 * 60 * 1000;

  /**
   * @param {number} d Days before now.
   * @return {Date} The past date.
   */
  function daysAgo(d: number): Date {
    return new Date(now.getTime() - d * msPerDay);
  }

  /**
   * @param {number} count Number of votes.
   * @param {number} ageDays Age of every vote, in days.
   * @return {VoteRecord[]} That many votes, all at that age.
   */
  function votesAtAge(count: number, ageDays: number): VoteRecord[] {
    return Array.from({length: count}, () => ({
      createdAt: daysAgo(ageDays),
      weight: 1,
    }));
  }

  // Each fixture exercises a distinct point on the decay curve:
  //  - a clear winner (most votes, all fresh)
  //  - a close pair tied on raw vote count, decided by decay alone
  //  - a volume-vs-recency pair where more votes still loses
  //  - an exact tie, decided by assignRanks' documented tie-break
  const fixtures: {id: string; name: string; votes: VoteRecord[]}[] = [
    {id: "clear-winner", name: "Clear Winner", votes: votesAtAge(5, 0)},
    {id: "close-fresher", name: "Close Fresher", votes: votesAtAge(3, 5)},
    {id: "close-older", name: "Close Older", votes: votesAtAge(3, 15)},
    {id: "old-volume", name: "Old Volume", votes: votesAtAge(10, 270)},
    {id: "new-few", name: "New Few", votes: votesAtAge(2, 0)},
    {id: "tie-alpha", name: "Alpha Diner", votes: votesAtAge(4, 30)},
    {id: "tie-zebra", name: "Zebra Grill", votes: votesAtAge(4, 30)},
  ];

  test("exact rank order across the decay curve", () => {
    const scored: ScoredRestaurant[] = fixtures.map((f) => ({
      id: f.id,
      name: f.name,
      voteCount: f.votes.length,
      score: computeScore(f.votes, now, DEFAULT_HALF_LIFE_DAYS),
    }));

    const actualOrder = assignRanks(scored).map((r) => r.id);

    const expectedOrder = [
      // 5 fresh votes beats everything.
      "clear-winner",
      // Exact tie (4 votes each, both 30 days old): voteCount ties too,
      // so assignRanks falls through to alphabetical name.
      "tie-alpha",
      "tie-zebra",
      // Same vote count (3), different age: decay alone decides.
      "close-fresher",
      "close-older",
      // 2 fresh votes outranks 10 votes from 270 days ago (3 half-lives).
      "new-few",
      "old-volume",
    ];

    expect(actualOrder).toEqual(expectedOrder);
  });
});
