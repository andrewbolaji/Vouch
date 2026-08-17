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
 * Score units between adjacent curated positions.
 *
 * Expressed deliberately as "how many fresh votes does it take to
 * move one place", because that is the sentence the product has to be
 * able to say out loud. A fresh vote is worth exactly 1.0
 * (computeScore at age 0), so a step of 2.0 means one place costs two.
 *
 * Set to 2.0 rather than 1.0 on manipulation cost, not on feel. At
 * 1.0, nine friends buys rank 1 on launch day, and nine people is
 * nothing. At 2.0 it is seventeen. Money cannot buy rank here and
 * that is enforced at the rules layer; friends buying rank is the
 * same failure in a cheaper currency, and during the opening window
 * the baseline is the only thing in its way.
 *
 * See docs/FIX_B_DESIGN.md for the full table, including why 3.0 is
 * rejected.
 */
export const BASELINE_STEP = 2.0;

/**
 * City votes per restaurant at which the baseline reaches zero.
 *
 * Scales with city size, so a 10 restaurant city expires at 200 votes
 * and a 17 restaurant city at 340. A longer curated list is a larger
 * editorial claim and needs proportionally more signal before its
 * curation should stop mattering. Scaling also keeps the step, which
 * is the user-facing quantity, meaning the same thing in every city.
 */
export const BASELINE_EXPIRY_VOTES_PER_RESTAURANT = 20;

/**
 * How much of the curated baseline still applies, from 1 down to 0.
 *
 * Linear, because it has to reach exactly zero at a stated number.
 * An exponential only ever gets small, and the whole point is a hard
 * stop after which rank is votes and nothing else. A thumb that never
 * lifts makes "locals decide" quietly untrue, and quietly is the part
 * that matters, because nobody would be able to tell.
 *
 * Driven by lifetime city votes rather than by the calendar: a city
 * nobody has voted in has learned nothing, and waiting does not
 * change that. Because that count only ever grows, this function is
 * monotonically non-increasing, which is a required property and is
 * asserted by its own test rather than left to be inherited.
 *
 * @param {number} cityVotes Lifetime vote documents in the city.
 * @param {number} restaurantCount Restaurants in the city.
 * @return {number} Weight in [0, 1].
 */
export function baselineWeight(
  cityVotes: number,
  restaurantCount: number
): number {
  const expiry = restaurantCount * BASELINE_EXPIRY_VOTES_PER_RESTAURANT;
  // A city with no restaurants has no baseline and no division.
  if (expiry <= 0) return 0;
  // Clamped at 0. Past expiry the expression goes negative, and a
  // negative baseline would penalise a curated restaurant for its
  // position, which is the opposite of the intent and hard to spot.
  return Math.max(0, 1 - cityVotes / expiry);
}

/**
 * The baseline score for one curated position.
 *
 * Takes `displayOrder`, never `rank`. That is not a preference:
 * `rank` is the output of the computation this feeds, so deriving
 * from it would make the baseline that produced today's order an
 * input to tomorrow's. The order would lock itself in, votes could
 * never dislodge it, and a restaurant that rose on real votes would
 * then be defended by a baseline it earned by rising.
 *
 * `displayOrder` is safe to read because nothing in the pipeline
 * writes it: it is set once by the launch-order scripts and read
 * thereafter. rank_recompute must never be extended to write it.
 *
 * A restaurant with no `displayOrder` gets zero. Nobody curated it,
 * so nobody is vouching for its position, and it competes on votes
 * alone. That is also exactly what the open list produces.
 *
 * @param {number|null|undefined} displayOrder The curated position.
 * @param {number} restaurantCount Restaurants in the city.
 * @param {number} cityVotes Lifetime vote documents in the city.
 * @return {number} The baseline score, 0 or greater.
 */
export function baselineFor(
  displayOrder: number | null | undefined,
  restaurantCount: number,
  cityVotes: number
): number {
  if (typeof displayOrder !== "number") return 0;
  const positionValue =
    (restaurantCount - displayOrder + 1) * BASELINE_STEP;
  // A displayOrder beyond the city's size would produce a negative
  // position value, which would penalise rather than support.
  if (positionValue <= 0) return 0;
  return positionValue * baselineWeight(cityVotes, restaurantCount);
}

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
