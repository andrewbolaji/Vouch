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

import {computeScore, assignRanks, DEFAULT_HALF_LIFE_DAYS,
  baselineWeight, baselineFor, BASELINE_STEP} from "./rank_engine";
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

// ================================================================
// Fix B step 2: the curated baseline.
//
// Fix A fixed the zero-vote case. This fixes the one-vote inversion,
// measured by execution rather than argued: a single vote on Lotus
// Seafood produced score 0.997 against nine restaurants at 0.000, so
// one person could reorder a curated Top 10 overnight.
//
// See docs/FIX_B_DESIGN.md for why the constants are what they are.
// BASELINE_STEP is 2.0 because at 1.0 nine friends buys rank 1 on
// launch day.
// ================================================================
describe("baselineWeight", () => {
  test("is 1 at zero votes and exactly 0 at the expiry", () => {
    expect(baselineWeight(0, 10)).toBe(1);
    // 10 restaurants * 20 = 200.
    expect(baselineWeight(200, 10)).toBe(0);
    // Atlanta: 17 * 20 = 340.
    expect(baselineWeight(340, 17)).toBe(0);
  });

  test("is monotonically non-increasing and never negative", () => {
    // Required property, asserted rather than inherited. Decay is
    // driven by lifetime city votes, which only grow, so this holds
    // "for free" via something two layers away. That is exactly how
    // the composition-root class of bug gets in: the property holds
    // because of something nobody asserts, and then somebody changes
    // the something. A weight that can rise is a list that un-learns.
    let previous = Infinity;
    for (let votes = 0; votes <= 1000; votes++) {
      const w = baselineWeight(votes, 10);
      expect(w).toBeLessThanOrEqual(previous);
      expect(w).toBeGreaterThanOrEqual(0);
      previous = w;
    }
  });

  test("clamps at zero rather than going negative past expiry", () => {
    // 1 - votes/expiry goes negative past expiry, and a negative
    // baseline would actively penalise a curated restaurant for its
    // position, which is the opposite of the intent and would be very
    // hard to notice.
    expect(baselineWeight(10_000, 10)).toBe(0);
    expect(baselineWeight(Number.MAX_SAFE_INTEGER, 10)).toBe(0);
  });

  test("a city with no restaurants does not divide by zero", () => {
    expect(Number.isFinite(baselineWeight(0, 0))).toBe(true);
    expect(baselineWeight(0, 0)).toBe(0);
  });
});

describe("baselineFor", () => {
  const n = 10;

  test("rank 1 gets the largest baseline, rank n the smallest", () => {
    // At 20 city votes the weight is 0.90.
    expect(baselineFor(1, n, 20)).toBeCloseTo(18.0, 5);
    expect(baselineFor(5, n, 20)).toBeCloseTo(10.8, 5);
    expect(baselineFor(10, n, 20)).toBeCloseTo(1.8, 5);
  });

  test("adjacent positions differ by exactly one step, scaled", () => {
    // The user-facing quantity: what one place is worth. This is what
    // has to mean the same thing in Houston and in Atlanta, which is
    // why the baseline scales with n rather than using a fixed top.
    const w = baselineWeight(20, n);
    expect(baselineFor(4, n, 20) - baselineFor(5, n, 20))
      .toBeCloseTo(BASELINE_STEP * w, 5);
  });

  test("a restaurant with no displayOrder gets no baseline", () => {
    // Nobody curated it, so nobody is vouching for its position. It
    // competes on votes alone. This is also what the open list
    // produces: a user-suggested restaurant arrives with no curated
    // position by definition.
    expect(baselineFor(undefined, n, 20)).toBe(0);
    expect(baselineFor(null, n, 20)).toBe(0);
  });

  test("every baseline is exactly zero once the city has expired", () => {
    for (let d = 1; d <= n; d++) {
      expect(baselineFor(d, n, 200)).toBe(0);
    }
  });

  // Deliberately NOT tested here by asserting baselineFor.length.
  // Arity proves nothing: a caller can still pass rank in the
  // displayOrder slot, which is the actual failure mode. That the
  // baseline follows displayOrder rather than rank is asserted at the
  // wiring, in index.test.ts, with a fixture where the two disagree.
});

describe("the one-vote inversion, before and after", () => {
  const n = 10;

  test("one vote on rank 10 no longer reaches rank 1", () => {
    const cityVotes = 20;
    const freshVote = 0.997;

    const challenger = freshVote + baselineFor(10, n, cityVotes);
    const incumbent = 0 + baselineFor(1, n, cityVotes);
    expect(challenger).toBeLessThan(incumbent);

    // It does not even pass rank 9 on a single vote at STEP 2.0.
    expect(challenger).toBeLessThan(baselineFor(9, n, cityVotes));
  });

  test("votes still beat curation once there are enough of them", () => {
    // The baseline is a prior, not a floor. Seventeen net votes takes
    // curated last to first at launch, which is the manipulation cost
    // the constant was chosen for.
    const cityVotes = 20;
    const challenger = 17 + baselineFor(10, n, cityVotes);
    const incumbent = 0 + baselineFor(1, n, cityVotes);
    expect(challenger).toBeGreaterThan(incumbent);
  });
});
