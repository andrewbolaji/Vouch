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
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as functions from "firebase-functions";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {applyVoteCreated, applyVoteDeleted} from "./vote_aggregation";
import {deleteUserData} from "./user_cleanup";
import {recomputeAllRanks} from "./rank_recompute";

initializeApp();
const db = getFirestore();

setGlobalOptions({maxInstances: 10, region: "us-central1"});

// ---------------------------------------------------------------------------
// 1. onVoteCreated / onVoteDeleted
//    Firestore trigger on /restaurants/{restaurantId}/votes/{userId}
//    Delegates to shared applyVoteCreated/applyVoteDeleted functions.
// ---------------------------------------------------------------------------

export const onVoteCreated = onDocumentCreated(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    await applyVoteCreated(db, event.params.restaurantId);
  }
);

export const onVoteDeleted = onDocumentDeleted(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    await applyVoteDeleted(db, event.params.restaurantId);
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
//    Delegates to shared deleteUserData function for Firestore cleanup.
//    Comments are anonymized (not deleted) to preserve reply threads.
//    Votes are deleted, letting onVoteDeleted decrement aggregates.
// ---------------------------------------------------------------------------

export const onUserDeleted = functions
  .runWith({maxInstances: 10})
  .region("us-central1")
  .auth.user()
  .onDelete(async (user) => {
    await deleteUserData(db, user.uid);
  });

// ---------------------------------------------------------------------------
// 4. recomputeRanks (scheduled daily at 06:00 UTC)
//    Reads vote subcollections, computes time-decayed scores,
//    assigns contiguous ranks 1..N per city.
// ---------------------------------------------------------------------------

export const recomputeRanks = onSchedule(
  {schedule: "0 6 * * *", timeZone: "UTC"},
  async () => {
    await recomputeAllRanks(db);
    logger.info("Daily rank recomputation complete");
  }
);

// ---------------------------------------------------------------------------
// 5. Custom claim setter (deferred)
// ---------------------------------------------------------------------------

// TODO(vouch): Add setMembershipClaim Cloud Function.
// Triggered by RevenueCat webhook when a purchase is verified.
// Sets custom claim { membershipTier: 'localsPass' | 'cityInsider' } on the user's auth token.
// Deferred to the RevenueCat integration block.
