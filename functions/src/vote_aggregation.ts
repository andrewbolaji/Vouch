/**
 * Shared vote aggregation logic.
 *
 * Called by the onVoteCreated/onVoteDeleted Firestore triggers
 * in production and directly by tests. Single source of truth
 * for how vote counts are adjusted, and for the per-user
 * votedRestaurantIds list the client reads on sign-in.
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

/**
 * Adds a restaurant to the user's own votedRestaurantIds list.
 *
 * This list is what the client reads once on sign-in to know which
 * vote buttons to fill in, replacing a per-restaurant read of the
 * votes subcollection (one read per restaurant in the catalogue, on
 * every signed-in launch). It is a denormalized convenience copy:
 * the votes subcollection remains the source of truth, and
 * rank_recompute never reads this field.
 *
 * Written with set(..., merge) rather than update() so a user doc
 * that does not exist yet is created rather than throwing NOT_FOUND,
 * the same failure mode the restaurant aggregation guards above
 * were added for.
 *
 * arrayUnion is idempotent under redelivery, so an at-least-once
 * retry cannot double-add. It is NOT order-independent, and
 * Firestore trigger delivery is unordered: a fast vote then unvote
 * whose events land reversed converges to the wrong answer, not
 * merely a stale one. That is why the client repairs this list per
 * restaurant on read (AppState.repairVoteStateForRestaurant) rather
 * than trusting it outright.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} userId The voter's uid, which is the vote doc ID.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function addVotedRestaurant(
  db: FirebaseFirestore.Firestore,
  userId: string,
  restaurantId: string
): Promise<void> {
  await db.collection("users").doc(userId).set(
    {votedRestaurantIds: FieldValue.arrayUnion(restaurantId)},
    {merge: true}
  );
  logger.info(
    `Added ${restaurantId} to votedRestaurantIds for user ${userId}`
  );
}

/**
 * Removes a restaurant from the user's own votedRestaurantIds list.
 *
 * See addVotedRestaurant for why this is set(..., merge) rather than
 * update(), and for the ordering caveat that makes the client-side
 * on-read repair load-bearing rather than cosmetic.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} userId The voter's uid, which is the vote doc ID.
 * @param {string} restaurantId The restaurant doc ID.
 */
export async function removeVotedRestaurant(
  db: FirebaseFirestore.Firestore,
  userId: string,
  restaurantId: string
): Promise<void> {
  await db.collection("users").doc(userId).set(
    {votedRestaurantIds: FieldValue.arrayRemove(restaurantId)},
    {merge: true}
  );
  logger.info(
    `Removed ${restaurantId} from votedRestaurantIds for user ${userId}`
  );
}
