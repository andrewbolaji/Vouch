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
      // Exact tie (4 votes each, both 30 days old): voteCount ties
      // too, and neither fixture sets displayOrder, so both are
      // sorted last-equal and assignRanks falls through to id.
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

  test("a future-dated vote cannot outrank a fresh vote", () => {
    // The rule now rejects a client-supplied createdAt at write time
    // (createdAt == request.time), but this is the second layer: even
    // a bad row already in the database cannot blow up a score. A
    // vote dated a year in the future has negative age; without a
    // clamp, exp(-decayRate * negativeAge) exceeds 1 and the vote is
    // worth more than a real one cast today.
    const scored: ScoredRestaurant[] = [
      {
        id: "future-vote",
        name: "Future Vote",
        voteCount: 1,
        score: computeScore(votesAtAge(1, -365), now, DEFAULT_HALF_LIFE_DAYS),
      },
      {
        id: "fresh-vote",
        name: "Fresh Vote",
        voteCount: 2,
        score: computeScore(votesAtAge(2, 0), now, DEFAULT_HALF_LIFE_DAYS),
      },
    ];

    const actualOrder = assignRanks(scored).map((r) => r.id);
    expect(actualOrder).toEqual(["fresh-vote", "future-vote"]);
  });
});

// ================================================================
// Tie-break: curated order, not alphabetical
//
// A city launches with zero votes. Every score is 0 and every
// voteCount is 0, so every comparison falls through to the final
// tie-break, and that tie-break alone decides the entire published
// list. The first nightly run is therefore the highest-stakes run
// there is, and it happens before a single user has voted.
// ================================================================
describe("assignRanks tie-break on a zero-vote city", () => {
  // The curated Houston order. displayOrder is written alongside rank
  // by scripts/set_houston_launch_order.js:140, so it is the record
  // of what a human decided, and it is the only field that survives a
  // recompute wiping rank.
  const curated = [
    {id: "hou-1", name: "Mensho", displayOrder: 1},
    {id: "hou-11", name: "Tacos Los Brothers", displayOrder: 2},
    {id: "hou-12", name: "Crave Suya", displayOrder: 3},
    {id: "hou-13", name: "The Peri Peri Factory", displayOrder: 4},
    {id: "hou-9", name: "Corkscrew BBQ", displayOrder: 5},
  ];

  test("zero votes leaves the curated order untouched", () => {
    const scored: ScoredRestaurant[] = curated.map((c) => ({
      id: c.id,
      name: c.name,
      voteCount: 0,
      score: 0,
      displayOrder: c.displayOrder,
    }));

    expect(assignRanks(scored).map((r) => r.id)).toEqual(
      curated.map((c) => c.id)
    );
  });

  test("input order does not matter, displayOrder does", () => {
    // Same set, shuffled on the way in. Firestore returns documents
    // in whatever order it likes, so an engine that happened to
    // preserve input order would still be wrong.
    const shuffled = [
      curated[3], curated[0], curated[4], curated[2], curated[1],
    ];
    const scored: ScoredRestaurant[] = shuffled.map((c) => ({
      id: c.id,
      name: c.name,
      voteCount: 0,
      score: 0,
      displayOrder: c.displayOrder,
    }));

    expect(assignRanks(scored).map((r) => r.id)).toEqual(
      curated.map((c) => c.id)
    );
  });

  test("a restaurant with no displayOrder sorts last, not first", () => {
    // scripts/seed_houston_new.js writes displayOrder 9999 for a new
    // candidate, but a document written by any other path may not
    // carry the field at all. Undefined must not read as 0 and jump
    // the queue ahead of the curated list.
    const scored: ScoredRestaurant[] = [
      {id: "newcomer", name: "AAA Newcomer", voteCount: 0, score: 0},
      {id: "hou-1", name: "Mensho", voteCount: 0, score: 0, displayOrder: 1},
      {id: "candidate", name: "BBB Candidate", voteCount: 0, score: 0,
        displayOrder: 9999},
    ];

    const order = assignRanks(scored).map((r) => r.id);
    expect(order[0]).toBe("hou-1");
    expect(order).toEqual(["hou-1", "candidate", "newcomer"]);
  });

  test("votes still outrank curation", () => {
    // The tie-break is only a tie-break. One real vote must still
    // beat a hand-picked number one, or the list stops being
    // vote-ranked.
    const scored: ScoredRestaurant[] = [
      {id: "hou-1", name: "Mensho", voteCount: 0, score: 0, displayOrder: 1},
      {id: "hou-9", name: "Corkscrew BBQ", voteCount: 1, score: 0.997,
        displayOrder: 5},
    ];

    expect(assignRanks(scored).map((r) => r.id)).toEqual(["hou-9", "hou-1"]);
  });
});
