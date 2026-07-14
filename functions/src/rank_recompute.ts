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

    // -- Audit logging --
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
