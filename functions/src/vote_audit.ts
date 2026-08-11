/**
 * Append-only vote audit trail.
 *
 * Writes one document per vote create/delete to the top-level
 * voteEvents collection, doc ID is the Firestore event id so an
 * at-least-once trigger retry overwrites the same document instead
 * of writing a second one.
 *
 * Called by the onVoteCreated/onVoteDeleted triggers in index.ts,
 * before the vote count aggregation, so a fabricated or orphaned
 * restaurantId that makes the aggregation update throw still leaves
 * an audit record behind.
 */

import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Looks up a restaurant's cityId. Never throws: a missing document
 * or a failed read both resolve to null rather than blocking the
 * audit write that called this. A null cityId is itself a signal,
 * the 163 fabricated votes found in production on 2026-08-07 were
 * under restaurant IDs with no restaurant document at all.
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 * @return {Promise<string | null>} The cityId, or null.
 */
async function lookupCityId(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<string | null> {
  try {
    const snap = await db.collection("restaurants").doc(restaurantId).get();
    if (!snap.exists) return null;
    const cityId = snap.data()?.cityId;
    return typeof cityId === "string" ? cityId : null;
  } catch (err) {
    logger.warn(
      `voteEvents: cityId lookup failed for restaurant ${restaurantId}`,
      err
    );
    return null;
  }
}

/**
 * Records a vote create event.
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} eventId Firestore event id, used as the doc id.
 * @param {string} restaurantId The restaurant doc ID.
 * @param {string} userId The voter's uid.
 */
export async function recordVoteCreated(
  db: FirebaseFirestore.Firestore,
  eventId: string,
  restaurantId: string,
  userId: string
): Promise<void> {
  const cityId = await lookupCityId(db, restaurantId);
  await db.collection("voteEvents").doc(eventId).set({
    eventId,
    type: "create",
    userId,
    restaurantId,
    cityId,
    occurredAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Records a vote delete event.
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} eventId Firestore event id, used as the doc id.
 * @param {string} restaurantId The restaurant doc ID.
 * @param {string} userId The voter's uid.
 * @param {Timestamp | null} voteCreatedAt The createdAt field off the
 *   vote document being deleted, so we know how long it existed.
 */
export async function recordVoteDeleted(
  db: FirebaseFirestore.Firestore,
  eventId: string,
  restaurantId: string,
  userId: string,
  voteCreatedAt: Timestamp | null
): Promise<void> {
  const cityId = await lookupCityId(db, restaurantId);
  await db.collection("voteEvents").doc(eventId).set({
    eventId,
    type: "delete",
    userId,
    restaurantId,
    cityId,
    occurredAt: FieldValue.serverTimestamp(),
    voteCreatedAt: voteCreatedAt ?? null,
  });
}
