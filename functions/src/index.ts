/**
 * Vouch Cloud Functions
 *
 * Firebase Functions v2 API (firebase-functions v7+)
 * Region: us-central1
 */

import {setGlobalOptions} from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

setGlobalOptions({maxInstances: 10, region: "us-central1"});

// ---------------------------------------------------------------------------
// 1. onVoteCreated / onVoteDeleted
//    Firestore trigger on /restaurants/{restaurantId}/votes/{userId}
//    Uses O(1) incremental counters instead of re-counting.
// ---------------------------------------------------------------------------

export const onVoteCreated = onDocumentCreated(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    const restaurantId = event.params.restaurantId;
    const restaurantRef = db.collection("restaurants").doc(restaurantId);
    await restaurantRef.update({voteCount: FieldValue.increment(1)});
    logger.info(`Vote added for restaurant ${restaurantId}`);
  }
);

export const onVoteDeleted = onDocumentDeleted(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    const restaurantId = event.params.restaurantId;
    const restaurantRef = db.collection("restaurants").doc(restaurantId);
    await restaurantRef.update({voteCount: FieldValue.increment(-1)});
    logger.info(`Vote removed for restaurant ${restaurantId}`);
  }
);

// ---------------------------------------------------------------------------
// 2. submitSuggestion
//    HTTPS callable. Enforces a daily cap of 1 suggestion per user.
//    Writes suggestion + increments counter inside a transaction.
// ---------------------------------------------------------------------------

export const submitSuggestion = onCall(async (request) => {
  // Auth check
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to submit a suggestion."
    );
  }

  const uid = request.auth.uid;
  const {type, text, cityId} = request.data as {
    type: string;
    text: string;
    cityId?: string;
  };

  if (!type || !text) {
    throw new HttpsError(
      "invalid-argument",
      "Both 'type' and 'text' are required."
    );
  }

  // Determine today's date key in UTC (YYYY-MM-DD)
  const now = new Date();
  const dateKey = now.toISOString().split("T")[0];

  const counterRef = db
    .collection("users")
    .doc(uid)
    .collection("suggestionCounts")
    .doc(dateKey);

  const suggestionRef = db.collection("suggestions").doc();

  await db.runTransaction(async (tx) => {
    const counterSnap = await tx.get(counterRef);
    const currentCount = counterSnap.exists
      ? (counterSnap.data()?.count as number) ?? 0
      : 0;

    if (currentCount >= 1) {
      throw new HttpsError(
        "resource-exhausted",
        "You've hit the limit for today. Try again tomorrow."
      );
    }

    // Write the suggestion document
    tx.set(suggestionRef, {
      id: suggestionRef.id,
      userId: uid,
      type,
      text,
      cityId: cityId ?? null,
      createdAt: FieldValue.serverTimestamp(),
      status: "pending",
    });

    // Increment the daily counter
    tx.set(
      counterRef,
      {count: FieldValue.increment(1), date: dateKey},
      {merge: true}
    );
  });

  logger.info(`Suggestion ${suggestionRef.id} submitted by user ${uid}`);
  return {suggestionId: suggestionRef.id};
});

// ---------------------------------------------------------------------------
// 3. onUserDeleted
//    Firebase Auth trigger (onDelete).
//    Cleans up all Firestore data belonging to the deleted user.
//    Uses batch deletes for efficiency.
// ---------------------------------------------------------------------------

export const onUserDeleted = functions
  .runWith({maxInstances: 10})
  .region("us-central1")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    logger.info(`Cleaning up data for deleted user ${uid}`);

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

    // Delete /users/{uid}/suggestionCounts/* subcollection
    const countsDeleted = await deleteDocs(
      db.collection("users").doc(uid).collection("suggestionCounts")
    );
    logger.info(
      `Deleted ${countsDeleted} suggestionCounts docs for user ${uid}`
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

    // Delete all votes across all restaurants where doc ID == uid
    // Votes are stored at /restaurants/{restaurantId}/votes/{userId}
    // Use collectionGroup query to find all vote docs with matching ID.
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

    // Delete all comments across all restaurants where userId == uid
    const commentsDeleted = await deleteDocs(
      db.collectionGroup("comments").where("userId", "==", uid)
    );
    logger.info(
      `Deleted ${commentsDeleted} comments for user ${uid}`
    );

    logger.info(`Cleanup complete for user ${uid}`);
  });

// ---------------------------------------------------------------------------
// 4. Custom claim setter (deferred)
// ---------------------------------------------------------------------------

// TODO(vouch): Add setMembershipClaim Cloud Function.
// Triggered by RevenueCat webhook when a purchase is verified.
// Sets custom claim { membershipTier: 'localsPass' | 'cityInsider' } on the user's auth token.
// Deferred to the RevenueCat integration block.
