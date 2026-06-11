/**
 * Rank recomputation orchestrator.
 *
 * Reads vote subcollections from Firestore, delegates score math
 * to rank_engine.ts, and batch-writes updated rank + rankScore
 * to restaurant docs.
 *
 * Called by the scheduled Cloud Function and directly by tests.
 */

import * as logger from "firebase-functions/logger";
import {
  computeScore,
  assignRanks,
  DEFAULT_HALF_LIFE_DAYS,
} from "./rank_engine.js";
import type {VoteRecord, ScoredRestaurant} from "./rank_engine.js";

/**
 * Recomputes ranks for all restaurants across all cities.
 *
 * For each city:
 *   1. Read all restaurants where cityId == city.
 *   2. For each restaurant, read all vote docs.
 *   3. Compute time-decayed score.
 *   4. Assign contiguous ranks 1..N.
 *   5. Batch-write rank and rankScore to each restaurant doc.
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

    // Get all restaurants for this city
    const restaurantsSnap = await db
      .collection("restaurants")
      .where("cityId", "==", cityId)
      .get();

    if (restaurantsSnap.empty) {
      logger.info(`No restaurants for city ${cityId}, skipping`);
      continue;
    }

    // Compute scores
    const scored: ScoredRestaurant[] = [];

    for (const restDoc of restaurantsSnap.docs) {
      const restData = restDoc.data();
      const votesSnap = await restDoc.ref.collection("votes").get();

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
        voteCount: (restData.voteCount as number) ?? 0,
        name: (restData.name as string) ?? "",
      });
    }

    // Assign ranks
    const ranked = assignRanks(scored);

    // Batch-write new ranks
    const batch = db.batch();
    for (const r of ranked) {
      const ref = db.collection("restaurants").doc(r.id);
      batch.update(ref, {
        rank: r.rank,
        rankScore: Math.round(r.score * 1000) / 1000,
      });
    }
    await batch.commit();

    logger.info(
      `Recomputed ranks for city ${cityId}: ` +
      `${ranked.length} restaurants ranked`
    );
  }
}
