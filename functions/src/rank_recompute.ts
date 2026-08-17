/**
 * Rank recomputation orchestrator.
 *
 * Reads vote subcollections from Firestore, delegates score math
 * to rank_engine.ts, and batch-writes updated rank + rankScore +
 * voteCount to restaurant docs.
 *
 * voteCount is also maintained incrementally by
 * vote_aggregation.ts on every vote create/delete, via
 * FieldValue.increment with no idempotency guard against Cloud
 * Functions' at-least-once retry delivery, so a retried trigger
 * invocation could double count it there. Writing the true count
 * here every night, computed from the same vote subcollection read
 * this function already does for scoring, corrects any such drift
 * by morning at zero extra read cost. See docs/DECISIONS.md for why
 * this replaces adding a transaction or dedup marker to the
 * increment path instead.
 *
 * Called by the scheduled Cloud Function and directly by tests.
 */

import * as logger from "firebase-functions/logger";
import {
  computeScore,
  assignRanks,
  baselineFor,
  baselineWeight,
  BASELINE_STEP,
  BASELINE_EXPIRY_VOTES_PER_RESTAURANT,
  DEFAULT_HALF_LIFE_DAYS,
} from "./rank_engine.js";
import type {
  VoteRecord,
  ScoredRestaurant,
  RankedRestaurant,
} from "./rank_engine.js";

/**
 * Recomputes ranks for all restaurants across all cities.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {Date} now Reference time for decay.
 * @param {number} halfLifeDays Decay half-life in days.
 * @param {Map} previousRanks Optional previous ranks for drift detection.
 */
export async function recomputeAllRanks(
  db: FirebaseFirestore.Firestore,
  now: Date = new Date(),
  halfLifeDays: number = DEFAULT_HALF_LIFE_DAYS
): Promise<void> {
  // Get all cities
  const citiesSnap = await db.collection("cities").get();
  if (citiesSnap.empty) {
    logger.info("No cities found, skipping rank recomputation");
    return;
  }

  for (const cityDoc of citiesSnap.docs) {
    const cityId = cityDoc.id;
    const cityName = (cityDoc.data().name as string) ?? cityId;

    // Get all restaurants for this city
    const restaurantsSnap = await db
      .collection("restaurants")
      .where("cityId", "==", cityId)
      .get();

    if (restaurantsSnap.empty) {
      logger.warn(
        "[rank] ANOMALY: zero restaurants for live city " +
        `${cityName} (${cityId})`
      );
      continue;
    }

    // Snapshot previous ranks for drift detection
    const previousRanks = new Map<string, number>();
    for (const doc of restaurantsSnap.docs) {
      const data = doc.data();
      if (typeof data.rank === "number") {
        previousRanks.set(doc.id, data.rank as number);
      }
    }

    // Compute scores
    const scored: ScoredRestaurant[] = [];
    const trueVoteCountById = new Map<string, number>();
    let cityVoteTotal = 0;

    for (const restDoc of restaurantsSnap.docs) {
      const votesSnap = await restDoc.ref.collection("votes").get();
      trueVoteCountById.set(restDoc.id, votesSnap.size);
      cityVoteTotal += votesSnap.size;

      const votes: VoteRecord[] = votesSnap.docs
        .map((vDoc) => {
          const data = vDoc.data();
          const ts = data.createdAt;
          if (!ts || !ts.toDate) return null;
          return {
            createdAt: ts.toDate() as Date,
            weight: (data.weight as number) ?? 1,
          };
        })
        .filter((v): v is VoteRecord => v !== null);

      const score = computeScore(votes, now, halfLifeDays);

      scored.push({
        id: restDoc.id,
        score,
        // The true count from the read above, not the possibly
        // stale restaurant.voteCount field, so the tie-break in
        // assignRanks sorts on the same number this function is
        // about to write back.
        voteCount: votesSnap.size,
        name: (restDoc.data().name as string) ?? "",
        // The curated position, and the reason this recompute does
        // not scramble a launch list that has no votes yet. Passed
        // through as-is: undefined means the document never went
        // through a launch-order script, and assignRanks sorts that
        // last rather than treating it as position 0.
        displayOrder: restDoc.data().displayOrder as number | undefined,
      });
    }

    // The curated baseline. Fix B.
    //
    // Added as a separate additive term at rank time, never as a vote
    // and never through vote weight. firestore.rules:82 enforces
    // weight == 1 on every vote write and the rules suite pins the
    // denial, and that guarantee is what makes "money cannot buy
    // rank" true rather than aspirational. Nothing here creates a
    // vote document or touches a weight.
    //
    // Keyed on displayOrder, never on rank. rank is the output this
    // computation produces, so feeding it back would lock the order
    // in and votes could never dislodge it.
    const restaurantCount = restaurantsSnap.size;
    const weight = baselineWeight(cityVoteTotal, restaurantCount);
    const baselineById = new Map<string, number>();
    for (const r of scored) {
      const baseline = baselineFor(
        r.displayOrder,
        restaurantCount,
        cityVoteTotal
      );
      baselineById.set(r.id, baseline);
      r.score += baseline;
    }

    // The zero-vote guard. Fix B, and the outer layer of it.
    //
    // A city that has cast no votes has produced no evidence, so
    // there is nothing for a ranking pass to act on. Every score is
    // 0, every voteCount is 0, and the published order would come
    // entirely out of whichever tie-break happens to be last. Before
    // Fix A that tie-break was alphabetical, and running it against
    // real Houston data moved Mensho from 1 to 6 with nobody voting.
    //
    // Skipping before the batch is built, rather than writing the
    // same values back, is deliberate. It is the strongest of the
    // three protections in docs/FIX_B_DESIGN.md because it does not
    // depend on any of the baseline arithmetic being correct, and it
    // means a freshly published city keeps exactly the ranks it was
    // seeded with until a real person votes.
    if (cityVoteTotal === 0) {
      logger.info(
        `[rank] ${cityName} (${cityId}): 0 votes, skipped. ` +
        `${restaurantsSnap.size} restaurants left untouched.`
      );
      continue;
    }

    // Assign ranks
    const ranked = assignRanks(scored);

    // Batch-write new ranks and the true, reconciled voteCount
    const batch = db.batch();
    for (const r of ranked) {
      const ref = db.collection("restaurants").doc(r.id);
      const baseline = baselineById.get(r.id) ?? 0;
      batch.update(ref, {
        rank: r.rank,
        // The total that produced the rank, baseline included.
        rankScore: Math.round(r.score * 1000) / 1000,
        // Written for observability and NEVER read back as an input.
        // That distinction is the lesson of this remediation:
        // cities.restaurantCount and restaurants.voteCount both
        // drifted precisely because a stored value was read as truth.
        // A derived value written only to be looked at cannot drift
        // into being wrong, because nothing depends on it. The vote
        // component is rankScore minus this.
        baselineScore: Math.round(baseline * 1000) / 1000,
        voteCount: trueVoteCountById.get(r.id) ?? 0,
      });
    }
    // The city's current baseline weight, written once, in the same
    // batch as the ranks it produced.
    //
    // The city screen needs this to decide whether to show the
    // opening-list line, and it must READ it rather than recompute
    // it. A client-side copy of the curve would be a second
    // implementation that drifts against this one, and the two
    // disagreeing means the app says the list is still opening while
    // the ranking has already stopped protecting it, or the reverse.
    // One writer, one number, read-only everywhere else.
    batch.update(cityDoc.ref, {baselineWeight: weight});

    await batch.commit();

    // -- Audit logging --
    //
    // The baseline line, once per city per run. Without it "why did
    // the order change" has no answer, and the ranking becomes the
    // same kind of unexplainable box the alphabetical tie-break was.
    // It reports the weight that was actually applied, read from the
    // same variable the batch wrote, so the log cannot describe a
    // curve the run did not use.
    const expiryVotes = restaurantCount * BASELINE_EXPIRY_VOTES_PER_RESTAURANT;
    logger.info(
      `[rank] ${cityName} (${cityId}) baseline weight ` +
      `${weight.toFixed(3)} at ${cityVoteTotal}/${expiryVotes} votes, ` +
      `step ${BASELINE_STEP}. ` +
      (weight === 0 ?
        "EXPIRED, rank is votes alone from here." :
        `${expiryVotes - cityVoteTotal} votes until it expires.`)
    );

    logCitySummary(cityName, cityId, ranked, scored, previousRanks);
  }
}

/**
 * Logs a compact per-city summary and any anomaly warnings.
 *
 * @param {string} cityName Display name of the city.
 * @param {string} cityId Firestore document ID of the city.
 * @param {RankedRestaurant[]} ranked Ranked results.
 * @param {ScoredRestaurant[]} scored Scored results.
 * @param {Map} previousRanks Previous rank map for drift.
 */
function logCitySummary(
  cityName: string,
  cityId: string,
  ranked: RankedRestaurant[],
  scored: ScoredRestaurant[],
  previousRanks: Map<string, number>
): void {
  // Build a name lookup from scored array
  const nameById = new Map<string, string>();
  for (const s of scored) {
    nameById.set(s.id, s.name);
  }

  // Top 3 summary
  const top3 = ranked
    .slice(0, 3)
    .map((r) => {
      const name = nameById.get(r.id) ?? r.id;
      const s = (Math.round(r.score * 100) / 100)
        .toFixed(2);
      return `#${r.rank} ${name} (${s})`;
    })
    .join(", ");

  logger.info(
    `[rank] ${cityName}: ${ranked.length} ranked. Top 3: ${top3}`
  );

  // Anomaly: all scores identical (and more than 1 restaurant)
  if (ranked.length > 1) {
    const scores = new Set(ranked.map((r) => Math.round(r.score * 1000)));
    if (scores.size === 1) {
      logger.warn(
        `[rank] ANOMALY: all ${ranked.length} scores identical ` +
        `in ${cityName} (${cityId})`
      );
    }
  }

  // Anomaly: rank jump > 5 positions
  for (const r of ranked) {
    const prev = previousRanks.get(r.id);
    if (prev !== undefined) {
      const jump = Math.abs(r.rank - prev);
      if (jump > 5) {
        const name = nameById.get(r.id) ?? r.id;
        logger.warn(
          `[rank] ANOMALY: ${name} jumped ${jump} positions ` +
          `(${prev} -> ${r.rank}) in ${cityName} (${cityId})`
        );
      }
    }
  }
}
