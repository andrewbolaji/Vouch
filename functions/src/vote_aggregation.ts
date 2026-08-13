/**
 * Shared vote aggregation logic.
 *
 * Called by the onVoteCreated/onVoteDeleted Firestore triggers
 * in production and directly by tests. Single source of truth
 * for how vote counts are adjusted.
 */

import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Increments the restaurant's voteCount by 1.
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function applyVoteCreated(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  const ref = db.collection("restaurants").doc(restaurantId);
  await ref.update({voteCount: FieldValue.increment(1)});
  logger.info(`Vote added for restaurant ${restaurantId}`);
}

/**
 * Decrements the restaurant's voteCount by 1.
 *
 * A restaurant's own deletion (onRestaurantDeleted,
 * restaurant_cleanup.ts) deletes its votes subcollection after the
 * restaurant doc itself is already gone, that is what an
 * onDocumentDeleted trigger means. Those deletes fire this same
 * onVoteDeleted trigger, so restaurantId can legitimately point at
 * nothing. update() throws NOT_FOUND on a missing document; this
 * checks first and skips rather than letting that throw propagate.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function applyVoteDeleted(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  const ref = db.collection("restaurants").doc(restaurantId);
  const snap = await ref.get();
  if (!snap.exists) {
    logger.info(
      `Vote removed for restaurant ${restaurantId}, but the ` +
      "restaurant doc is already gone, nothing to decrement"
    );
    return;
  }
  await ref.update({voteCount: FieldValue.increment(-1)});
  logger.info(`Vote removed for restaurant ${restaurantId}`);
}
