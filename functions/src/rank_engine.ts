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
}

/** The output of rank assignment. */
export interface RankedRestaurant {
  id: string;
  rank: number;
  score: number;
}

/** Default half-life in days. A vote loses half its value after this many days. */
export const DEFAULT_HALF_LIFE_DAYS = 90;

/**
 * Computes the time-decayed score for a set of votes.
 *
 * score = sum of: vote.weight * 2^(-daysSinceVote / halfLifeDays)
 *
 * A vote from today contributes its full weight.
 * A vote from halfLifeDays ago contributes half its weight.
 * A vote from 2 * halfLifeDays ago contributes a quarter, etc.
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
 * Assigns contiguous ranks 1..N to restaurants sorted by score descending.
 *
 * Tie-breaking: higher voteCount wins, then alphabetical by name.
 * No two restaurants share the same rank.
 */
export function assignRanks(
  restaurants: ScoredRestaurant[]
): RankedRestaurant[] {
  const sorted = [...restaurants].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (b.voteCount !== a.voteCount) return b.voteCount - a.voteCount;
    return a.name.localeCompare(b.name);
  });

  return sorted.map((r, i) => ({
    id: r.id,
    rank: i + 1,
    score: r.score,
  }));
}
