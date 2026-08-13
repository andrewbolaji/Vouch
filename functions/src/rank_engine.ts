/**
 * Pure ranking engine. No Firestore imports.
 *
 * Called by the recomputeRanks orchestrator and directly by tests.
 * Single source of truth for how votes become rank scores and
 * how scores become rank positions.
 */

/** A single vote record with the fields the engine needs. */
export interface VoteRecord {
  createdAt: Date;
  weight: number;
}

/** A restaurant with its computed score, used for rank assignment. */
export interface ScoredRestaurant {
  id: string;
  score: number;
  voteCount: number;
  name: string;
  /**
   * The curated position, written alongside rank by
   * scripts/set_houston_launch_order.js and set_atlanta_launch_order.js.
   * Optional because a document written by another path may not carry
   * it. Absent sorts last, see assignRanks.
   */
  displayOrder?: number;
}

/** The output of rank assignment. */
export interface RankedRestaurant {
  id: string;
  rank: number;
  score: number;
}

/** Default half-life in days. A vote loses half its
 * value after this many days. */
export const DEFAULT_HALF_LIFE_DAYS = 90;

/**
 * Computes the time-decayed score for a set of votes.
 *
 * score = sum of: vote.weight *
 *   2^(-daysSinceVote / halfLifeDays)
 *
 * A vote from today contributes its full weight.
 * A vote from halfLifeDays ago contributes half.
 *
 * @param {VoteRecord[]} votes The vote records.
 * @param {Date} now The reference time.
 * @param {number} halfLifeDays Decay half-life in days.
 * @return {number} The computed score.
 */
export function computeScore(
  votes: VoteRecord[],
  now: Date,
  halfLifeDays: number = DEFAULT_HALF_LIFE_DAYS
): number {
  if (votes.length === 0) return 0;

  const nowMs = now.getTime();
  const msPerDay = 24 * 60 * 60 * 1000;
  const decayRate = Math.LN2 / halfLifeDays;

  let score = 0;
  for (const vote of votes) {
    const ageMs = nowMs - vote.createdAt.getTime();
    const ageDays = Math.max(0, ageMs / msPerDay);
    score += vote.weight * Math.exp(-decayRate * ageDays);
  }

  return score;
}

/**
 * Assigns contiguous ranks 1..N sorted by score desc.
 *
 * Tie-breaking: higher voteCount wins, then lower displayOrder, then
 * id.
 *
 * The last tie-break used to be name.localeCompare, which was wrong
 * in the one case that matters most. A city launches with zero votes,
 * so every score and every voteCount is 0, every comparison falls
 * through to the last tie-break, and that tie-break alone decides the
 * published list. Measured on the emulator against real Houston data:
 * the curated order came out purely alphabetical, and Mensho went
 * from 1 to 6 without anybody voting.
 *
 * displayOrder is the record of what a human decided, written
 * alongside rank by scripts/set_houston_launch_order.js:140. It is
 * also the only copy of that decision that survives, since a
 * recompute overwrites rank itself.
 *
 * Absent displayOrder sorts last rather than reading as 0. A document
 * written outside the launch-order scripts would otherwise take rank
 * 1 ahead of the entire curated list.
 *
 * id is the final tie-break, so the result is deterministic when two
 * restaurants share a displayOrder. Deliberately not name: falling
 * back to alphabetical is the behaviour this function is fixing, and
 * a hidden alphabetical fallback is worse than a visible one.
 *
 * This is only a tie-break. A single real vote still outranks a
 * hand-picked number one, which is what keeps the list vote-ranked
 * rather than curated.
 *
 * @param {ScoredRestaurant[]} restaurants Input list.
 * @return {RankedRestaurant[]} Ranked output.
 */
export function assignRanks(
  restaurants: ScoredRestaurant[]
): RankedRestaurant[] {
  const curatedPosition = (r: ScoredRestaurant): number =>
    r.displayOrder ?? Number.POSITIVE_INFINITY;

  const sorted = [...restaurants].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (b.voteCount !== a.voteCount) return b.voteCount - a.voteCount;
    const aPos = curatedPosition(a);
    const bPos = curatedPosition(b);
    if (aPos !== bPos) return aPos - bPos;
    return a.id.localeCompare(b.id);
  });

  return sorted.map((r, i) => ({
    id: r.id,
    rank: i + 1,
    score: r.score,
  }));
}
