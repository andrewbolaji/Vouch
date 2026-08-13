/**
 * Shared restaurant data cleanup logic.
 *
 * Called by the onRestaurantDeleted trigger in production and
 * directly by tests. Firestore does not delete subcollections when
 * a parent document is deleted, so votes, comments, and insiderNotes
 * would otherwise survive indefinitely under a restaurantId nothing
 * points to. This is the traceable cause of the 163 orphaned vote
 * documents found in production on 2026-08-07: a launch-order script
 * deleted the restaurant doc without touching its votes subcollection.
 */

import * as logger from "firebase-functions/logger";

/**
 * Deletes every document in the votes, comments, and insiderNotes
 * subcollections of a restaurant that has just been deleted.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} restaurantId The deleted restaurant's doc ID.
 */
export async function deleteRestaurantData(
  db: FirebaseFirestore.Firestore,
  restaurantId: string
): Promise<void> {
  // Helper: delete all docs from a query in batches of 500
  const deleteDocs = async (
    query: FirebaseFirestore.Query
  ): Promise<number> => {
    let totalDeleted = 0;
    let snapshot = await query.limit(500).get();

    while (!snapshot.empty) {
      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      totalDeleted += snapshot.size;
      snapshot = await query.limit(500).get();
    }

    return totalDeleted;
  };

  const restaurantRef = db.collection("restaurants").doc(restaurantId);

  const votesDeleted = await deleteDocs(restaurantRef.collection("votes"));
  logger.info(
    `Deleted ${votesDeleted} votes for removed restaurant ${restaurantId}`
  );

  const commentsDeleted = await deleteDocs(
    restaurantRef.collection("comments")
  );
  logger.info(
    `Deleted ${commentsDeleted} comments for removed restaurant ${restaurantId}`
  );

  const notesDeleted = await deleteDocs(
    restaurantRef.collection("insiderNotes")
  );
  logger.info(
    `Deleted ${notesDeleted} insiderNotes for removed restaurant ` +
    restaurantId
  );

  logger.info(`Cleanup complete for removed restaurant ${restaurantId}`);
}
