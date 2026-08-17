/**
 * The open list, measured by execution rather than argued.
 *
 * docs/FIX_B_DESIGN.md sets the test in words: "if the baseline takes
 * hundreds of votes to expire, the open list is decorative". It then
 * answers it with arithmetic done by hand, for a curated restaurant
 * at rank 10. A restaurant that arrives through the open list is not
 * that: it has no `displayOrder`, so it carries no baseline at all,
 * and it also makes the city one restaurant larger, which raises every
 * incumbent's baseline and pushes the expiry out.
 *
 * These run the real engine over the real constants and pin the
 * answer. They are numbers rather than properties on purpose: if
 * BASELINE_STEP or the expiry is ever changed, the failure should say
 * "a newcomer now needs 40 votes to reach rank 1" rather than
 * "expected 2.0 to be 3.0", because the first sentence is the one
 * anybody can judge.
 *
 * Measured 2026-08-18, recorded in docs/OPEN_LIST_MEASUREMENT.md.
 */

import {
  assignRanks,
  baselineFor,
  BASELINE_EXPIRY_VOTES_PER_RESTAURANT,
} from "./rank_engine";
import type {ScoredRestaurant} from "./rank_engine";

const CURATED = 10;

/**
 * Ranks a city of curated restaurants plus one newcomer.
 *
 * Self-consistent: the newcomer's own votes count toward the city
 * total that drives the decay, because in a real city they do.
 *
 * @param {number} newcomerVotes Votes on the newcomer.
 * @param {number} eachIncumbent Votes held by each curated restaurant.
 * @return {number} The newcomer's rank.
 */
function rankOfNewcomer(
  newcomerVotes: number,
  eachIncumbent: number
): number {
  const n = CURATED + 1;
  const cityVotes = CURATED * eachIncumbent + newcomerVotes;

  const scored: ScoredRestaurant[] = [];
  for (let d = 1; d <= CURATED; d++) {
    scored.push({
      id: `cur-${d}`,
      score: eachIncumbent + baselineFor(d, n, cityVotes),
      voteCount: eachIncumbent,
      name: `Curated ${d}`,
      displayOrder: d,
    });
  }
  scored.push({
    id: "newcomer",
    // A fresh vote is worth exactly 1.0 at age 0, and an absent
    // displayOrder earns no baseline.
    score: newcomerVotes,
    voteCount: newcomerVotes,
    name: "Newcomer",
    displayOrder: undefined,
  });

  const ranked = assignRanks(scored);
  return ranked.find((r) => r.id === "newcomer")?.rank ?? -1;
}

/**
 * Fewest votes for the newcomer to reach a rank.
 *
 * @param {number} target The rank to reach.
 * @param {number} eachIncumbent Votes held by each incumbent.
 * @return {number} Votes needed, or -1 if unreachable under 2000.
 */
function votesToReach(target: number, eachIncumbent: number): number {
  for (let k = 0; k <= 2000; k++) {
    if (rankOfNewcomer(k, eachIncumbent) <= target) return k;
  }
  return -1;
}

describe("the open list is climbable, in numbers", () => {
  test("at launch, a newcomer reaches the list on 4 votes and the top on 20",
    () => {
      // Incumbents at zero votes is the launch case, and it is the
      // friendliest one for a newcomer. Everything else is harder.
      expect(votesToReach(10, 0)).toBe(4);
      expect(votesToReach(5, 0)).toBe(14);
      expect(votesToReach(1, 0)).toBe(20);
    });

  test("a newcomer costs 3 more than the design's headline number", () => {
    // FIX_B_DESIGN says "17 net votes from last to first". That is
    // true and it is about a *curated* rank 10, which carries its own
    // small baseline. A newcomer carries none and is one more
    // restaurant in the city, so it needs 20. The design's claim is
    // the right order of magnitude and the wrong number for this case,
    // which is the reason for measuring rather than quoting.
    expect(votesToReach(1, 0)).toBe(20);
  });

  test("incumbents holding real votes make it harder, as they should",
    () => {
      expect(votesToReach(10, 1)).toBe(5);
      expect(votesToReach(10, 5)).toBe(8);
      // Once curation has expired the contest is votes alone: every
      // incumbent sits on 20, and one more vote passes all of them at
      // once, which is why all four targets collapse to one number.
      expect(votesToReach(10, 20)).toBe(21);
      expect(votesToReach(1, 20)).toBe(21);
    });

  test("an absent displayOrder earns nothing, at any city size", () => {
    for (const cityVotes of [0, 20, 100, 1000]) {
      expect(baselineFor(undefined, 11, cityVotes)).toBe(0);
      expect(baselineFor(null, 11, cityVotes)).toBe(0);
    }
  });
});

describe("what a newcomer does to everyone else", () => {
  test("it raises every incumbent's baseline by one step", () => {
    // The non-obvious consequence, and the numbers are not what a
    // first guess produces. Two things move at once: position value is
    // (n - displayOrder + 1) * STEP, so every incumbent gains a step,
    // and the expiry scales with n, so the weight at a given vote
    // count is slightly higher too. The first version of this test
    // asserted 4.0 for the last case by counting only the step, and
    // the real answer is 3.636, because 4 * (1 - 20/220) is not 4.
    //
    // The effect is far from uniform. Curated first place gains 11
    // percent of its protection; curated last place doubles its own.
    expect(baselineFor(1, 10, 20)).toBeCloseTo(18.0, 5);
    expect(baselineFor(1, 11, 20)).toBeCloseTo(20.0, 5);
    expect(baselineFor(10, 10, 20)).toBeCloseTo(1.8, 5);
    expect(baselineFor(10, 11, 20)).toBeCloseTo(3.636, 3);
  });

  test("it pushes the expiry out by 20 votes", () => {
    // Expiry scales with the city's size, so every restaurant the
    // open list admits extends the window during which curation still
    // counts, for everybody.
    expect(10 * BASELINE_EXPIRY_VOTES_PER_RESTAURANT).toBe(200);
    expect(11 * BASELINE_EXPIRY_VOTES_PER_RESTAURANT).toBe(220);
  });
});
