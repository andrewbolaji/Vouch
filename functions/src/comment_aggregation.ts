/**
 * Shared comment aggregation logic.
 *
 * Called by the onCommentCreated/onCommentDeleted Firestore triggers
 * in production and directly by tests. Single source of truth
 * for how comment counts are adjusted.
 */

import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Increments the restaurant's commentCount by 1.
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function applyCommentCreated(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  const ref = db.collection("restaurants").doc(restaurantId);
  await ref.update({commentCount: FieldValue.increment(1)});
  logger.info(`Comment added for restaurant ${restaurantId}`);
}

/**
 * Decrements the restaurant's commentCount by 1.
 *
 * Same reason as applyVoteDeleted's equivalent guard
 * (vote_aggregation.ts): a restaurant's own deletion deletes its
 * comments subcollection after the restaurant doc is already gone,
 * firing this trigger against a restaurantId with nothing left to
 * update. Checked first instead of letting update()'s NOT_FOUND
 * throw propagate out of the trigger.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function applyCommentDeleted(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  const ref = db.collection("restaurants").doc(restaurantId);
  const snap = await ref.get();
  if (!snap.exists) {
    logger.info(
      `Comment removed for restaurant ${restaurantId}, but the ` +
      "restaurant doc is already gone, nothing to decrement"
    );
    return;
  }
  await ref.update({commentCount: FieldValue.increment(-1)});
  logger.info(`Comment removed for restaurant ${restaurantId}`);
}
