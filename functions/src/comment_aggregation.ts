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
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function applyCommentDeleted(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  const ref = db.collection("restaurants").doc(restaurantId);
  await ref.update({commentCount: FieldValue.increment(-1)});
  logger.info(`Comment removed for restaurant ${restaurantId}`);
}
