/**
 * Shared user data cleanup logic.
 *
 * Called by the onUserDeleted auth trigger in production and
 * directly by tests. Single source of truth for what "delete
 * a user's data" means.
 */

import * as logger from "firebase-functions/logger";

/**
 * Deletes or anonymizes all Firestore data for a user.
 *
 * Deletes: suggestionCounts, reportCounts, user doc,
 * suggestions, reports, and vote docs.
 * Anonymizes: comments to preserve reply threads.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} uid The user's UID.
 */
export async function deleteUserData(
  db: FirebaseFirestore.Firestore,
  uid: string
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

  // Helper: update all docs from a query in batches of 500
  const updateDocs = async (
    query: FirebaseFirestore.Query,
    data: Record<string, unknown>
  ): Promise<number> => {
    let totalUpdated = 0;
    let snapshot = await query.limit(500).get();

    while (!snapshot.empty) {
      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.update(doc.ref, data);
      }
      await batch.commit();
      totalUpdated += snapshot.size;
      snapshot = await query.limit(500).get();
    }

    return totalUpdated;
  };

  // Delete /users/{uid}/suggestionCounts/* subcollection
  const sugCountsDeleted = await deleteDocs(
    db.collection("users").doc(uid).collection("suggestionCounts")
  );
  logger.info(
    `Deleted ${sugCountsDeleted} suggestionCounts docs for user ${uid}`
  );

  // Delete /users/{uid}/reportCounts/* subcollection
  const repCountsDeleted = await deleteDocs(
    db.collection("users").doc(uid).collection("reportCounts")
  );
  logger.info(
    `Deleted ${repCountsDeleted} reportCounts docs for user ${uid}`
  );

  // Delete /users/{uid} document
  await db.collection("users").doc(uid).delete();
  logger.info(`Deleted /users/${uid} document`);

  // Delete all suggestions where userId == uid
  const suggestionsDeleted = await deleteDocs(
    db.collection("suggestions").where("userId", "==", uid)
  );
  logger.info(
    `Deleted ${suggestionsDeleted} suggestions for user ${uid}`
  );

  // Delete all reports where reporterUid == uid
  const reportsDeleted = await deleteDocs(
    db.collection("reports").where("reporterUid", "==", uid)
  );
  logger.info(
    `Deleted ${reportsDeleted} reports for user ${uid}`
  );

  // Delete all votes across all restaurants where doc ID == uid
  const votesSnapshot = await db.collectionGroup("votes").get();
  let votesDeleted = 0;
  const voteBatches: FirebaseFirestore.WriteBatch[] = [db.batch()];
  let opsInCurrentBatch = 0;

  for (const doc of votesSnapshot.docs) {
    if (doc.id === uid) {
      if (opsInCurrentBatch >= 500) {
        voteBatches.push(db.batch());
        opsInCurrentBatch = 0;
      }
      voteBatches[voteBatches.length - 1].delete(doc.ref);
      opsInCurrentBatch++;
      votesDeleted++;
    }
  }

  for (const batch of voteBatches) {
    if (votesDeleted > 0) {
      await batch.commit();
    }
  }
  logger.info(`Deleted ${votesDeleted} votes for user ${uid}`);

  // Anonymize all comments (preserve threads, remove personal data)
  const commentsAnonymized = await updateDocs(
    db.collectionGroup("comments").where("userId", "==", uid),
    {userId: "deleted", userName: "Deleted user", isInsider: false}
  );
  logger.info(
    `Anonymized ${commentsAnonymized} comments for user ${uid}`
  );

  logger.info(`Cleanup complete for user ${uid}`);
}
