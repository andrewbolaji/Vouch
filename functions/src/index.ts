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
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import * as auth from "firebase-functions/v1/auth";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {applyVoteCreated, applyVoteDeleted} from "./vote_aggregation";
import {recordVoteCreated, recordVoteDeleted} from "./vote_audit";
import {
  applyCommentCreated,
  applyCommentDeleted,
} from "./comment_aggregation";
import {containsBannedContent} from "./moderation";
import {deleteUserData} from "./user_cleanup";
import {deleteRestaurantData} from "./restaurant_cleanup";
import {recomputeAllRanks} from "./rank_recompute";
import {
  handleWebhookEvent,
  isValidAuth,
  RevenueCatWebhookEvent,
} from "./membership_webhook";

initializeApp();
const db = getFirestore();

setGlobalOptions({maxInstances: 10, region: "us-central1"});

// ---------------------------------------------------------------------------
// 1. onVoteCreated / onVoteDeleted
//    Firestore trigger on /restaurants/{restaurantId}/votes/{userId}
//    Delegates to shared applyVoteCreated/applyVoteDeleted functions.
//
//    The audit write (recordVoteCreated/recordVoteDeleted) runs first,
//    before the voteCount aggregation. applyVoteCreated/applyVoteDeleted
//    call .update() on the restaurant doc, which throws if that doc
//    does not exist, an orphaned or fabricated restaurantId is exactly
//    the case the audit trail exists to catch, so it must not depend
//    on the aggregation succeeding first.
// ---------------------------------------------------------------------------

export const onVoteCreated = onDocumentCreated(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    const weight =
      (event.data?.data()?.weight as number | undefined) ?? 1;
    await recordVoteCreated(
      db,
      event.id,
      event.params.restaurantId,
      event.params.userId,
      weight
    );
    await applyVoteCreated(db, event.params.restaurantId);
  }
);

export const onVoteDeleted = onDocumentDeleted(
  "restaurants/{restaurantId}/votes/{userId}",
  async (event) => {
    const deletedData = event.data?.data();
    const voteCreatedAt =
      (deletedData?.createdAt as Timestamp | undefined) ?? null;
    const weight = (deletedData?.weight as number | undefined) ?? 1;
    await recordVoteDeleted(
      db,
      event.id,
      event.params.restaurantId,
      event.params.userId,
      voteCreatedAt,
      weight
    );
    await applyVoteDeleted(db, event.params.restaurantId);
  }
);

// ---------------------------------------------------------------------------
// 2. onCommentCreated / onCommentDeleted
//    Firestore trigger on /restaurants/{restaurantId}/comments/{commentId}
//    Delegates to shared applyCommentCreated/applyCommentDeleted functions.
// ---------------------------------------------------------------------------

export const onCommentCreated = onDocumentCreated(
  "restaurants/{restaurantId}/comments/{commentId}",
  async (event) => {
    await applyCommentCreated(db, event.params.restaurantId);
  }
);

export const onCommentDeleted = onDocumentDeleted(
  "restaurants/{restaurantId}/comments/{commentId}",
  async (event) => {
    await applyCommentDeleted(db, event.params.restaurantId);
  }
);

// ---------------------------------------------------------------------------
// 3. submitSuggestion
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
    const currentCount = counterSnap.exists ?
      ((counterSnap.data()?.count as number) ?? 0) :
      0;

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
// submitComment
//    HTTPS callable. The only path that can create a comment document;
//    firestore.rules denies direct client creates outright. Runs the
//    content filter server-side before writing, so a rejected comment
//    is never created at all, not created then hidden. userName and
//    isInsider are resolved server-side, never trusted from the
//    client. Returns the created comment (id, createdAt, userName,
//    isInsider) so the client never has to fabricate an id.
//
//    onCommentCreated (above) still fires for every comment this
//    writes, the same as it would for any Firestore document
//    creation regardless of who created it. It needs no change.
// ---------------------------------------------------------------------------

export const submitComment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to comment."
    );
  }

  const uid = request.auth.uid;
  const {restaurantId, text, parentId} = request.data as {
    restaurantId: string;
    text: string;
    parentId?: string | null;
  };

  if (!restaurantId || !text) {
    throw new HttpsError(
      "invalid-argument",
      "Both 'restaurantId' and 'text' are required."
    );
  }
  if (text.length === 0 || text.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Comment text must be between 1 and 500 characters."
    );
  }

  if (containsBannedContent(text)) {
    logger.warn(`Comment rejected by content filter for user ${uid}`);
    throw new HttpsError(
      "failed-precondition",
      "That comment did not post. See our community guidelines."
    );
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const userName = (userSnap.data()?.displayName as string | undefined) ?? "";
  if (userName.trim().length === 0) {
    // Distinct from "invalid-argument" (bad text) and
    // "failed-precondition" (content filter): this is neither, it is
    // an account that is not ready to comment yet. The client needs
    // to tell these apart so it can offer the right fix (collect a
    // name) instead of a generic error.
    throw new HttpsError(
      "aborted",
      "Add a display name before commenting."
    );
  }
  const isInsider = request.auth.token.membershipTier === "cityInsider";

  const commentRef = db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("comments")
    .doc();
  const createdAt = Timestamp.now();

  await commentRef.set({
    restaurantId,
    userId: uid,
    userName,
    text,
    createdAt,
    parentId: parentId ?? null,
    isInsider,
  });

  logger.info(`Comment ${commentRef.id} submitted by user ${uid}`);

  return {
    id: commentRef.id,
    createdAt: createdAt.toDate().toISOString(),
    userName,
    isInsider,
  };
});

// ---------------------------------------------------------------------------
// 3. onUserDeleted
//    Firebase Auth trigger (onDelete).
//    Delegates to shared deleteUserData function for Firestore cleanup.
//    Comments are anonymized (not deleted) to preserve reply threads.
//    Votes are deleted, letting onVoteDeleted decrement aggregates.
// ---------------------------------------------------------------------------

export const onUserDeleted = auth
  .user()
  .onDelete(async (user: auth.UserRecord) => {
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
// 5. waitlistSignup
//    HTTPS endpoint for pre-launch landing page email collection.
//    Writes to the `waitlist` collection. Dedupes by normalized email.
// ---------------------------------------------------------------------------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const waitlistSignup = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ok: false, error: "method_not_allowed"});
      return;
    }

    try {
      const {email, city, source, website} = req.body as {
        email?: string;
        city?: string;
        source?: string;
        website?: string;
      };

      // Honeypot: bots fill hidden fields. Silently accept.
      if (website) {
        res.status(200).json({ok: true});
        return;
      }

      if (!email || !EMAIL_RE.test(email.trim())) {
        res.status(400).json({ok: false, error: "invalid_email"});
        return;
      }

      const normalized = email.trim().toLowerCase();
      // Firestore doc IDs cannot contain '/'. Replace with '__'.
      const docId = normalized.replace(/\//g, "__");
      const docRef = db.collection("waitlist").doc(docId);

      const existing = await docRef.get();
      if (existing.exists) {
        res.status(200).json({ok: true, duplicate: true});
        return;
      }

      await docRef.set({
        email: normalized,
        city: city?.trim() || null,
        source: source || "landing",
        createdAt: FieldValue.serverTimestamp(),
      });

      logger.info(`Waitlist signup: ${normalized}`);
      res.status(200).json({ok: true});
    } catch (err) {
      logger.error("waitlistSignup error", err);
      res.status(500).json({ok: false});
    }
  }
);

// ---------------------------------------------------------------------------
// 6. RevenueCat webhook: membership tier management
//
// HTTPS endpoint called by RevenueCat when a subscription event occurs.
// Validates the Authorization header against a secret stored in
// Google Cloud Secret Manager (set via: firebase functions:secrets:set
// REVENUECAT_WEBHOOK_SECRET). Never stored in source.
//
// On valid events: sets the membershipTier custom claim on the
// user's Auth token, then updates /users/{uid}.membershipTier.
// ---------------------------------------------------------------------------

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

export const onRevenueCatWebhook = onRequest(
  {cors: false, secrets: [revenueCatWebhookSecret]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "method_not_allowed"});
      return;
    }

    const secret = revenueCatWebhookSecret.value();
    if (!isValidAuth(req.headers.authorization, secret)) {
      res.status(401).json({error: "unauthorized"});
      return;
    }

    try {
      const body = req.body as {event?: RevenueCatWebhookEvent};
      const event = body.event;

      if (!event?.app_user_id || !event?.type) {
        logger.error(
          "[webhook] rejected: missing event fields",
          {body: JSON.stringify(req.body).slice(0, 500)}
        );
        res.status(400).json({error: "missing_event_fields"});
        return;
      }

      const result = await handleWebhookEvent(db, event);
      logger.info(
        `[webhook] ${event.type}: uid=${result.uid}, ` +
        `tier=${result.tier}, ` +
        `claimSet=${result.skipped ? "skipped (user not found)" : "yes"}`
      );
      res.status(200).json({ok: true});
    } catch (err) {
      logger.error("[webhook] FAILED", {
        error: err instanceof Error ? err.message : String(err),
        stack: err instanceof Error ? err.stack : undefined,
      });
      res.status(500).json({error: "internal"});
    }
  }
);

// ---------------------------------------------------------------------------
// 7. onRestaurantDeleted
//    Firestore trigger on /restaurants/{restaurantId}. Firestore does not
//    delete subcollections when a parent document is deleted, so votes,
//    comments, and insiderNotes would otherwise survive indefinitely under
//    a restaurantId nothing points to. This is the traceable cause of the
//    163 orphaned vote documents found in production on 2026-08-07: a
//    launch-order script deleted the restaurant doc without touching its
//    votes subcollection. Fires for every restaurant deletion, not just
//    the ones a known script runs, so a future script or a manual console
//    delete gets the same cleanup.
// ---------------------------------------------------------------------------

export const onRestaurantDeleted = onDocumentDeleted(
  "restaurants/{restaurantId}",
  async (event) => {
    await deleteRestaurantData(db, event.params.restaurantId);
  }
);
