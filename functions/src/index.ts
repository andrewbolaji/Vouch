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
import {
  applyVoteCreated,
  applyVoteDeleted,
  addVotedRestaurant,
  removeVotedRestaurant,
} from "./vote_aggregation";
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
  processWebhookEvent,
  isValidAuth,
  verifyWebhookSignature,
  REVENUECAT_SIGNATURE_HEADER,
  RevenueCatWebhookEvent,
} from "./membership_webhook";
import {
  reconcileMembershipFor,
  EntitlementLookupError,
  FetchLike,
} from "./revenuecat_api";
import {
  checkSignupInput,
  clientIpFrom,
  recordSignupAttempt,
  MAX_SIGNUPS_PER_IP_PER_DAY,
} from "./waitlist";

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
    // Last, so a failure maintaining this convenience list cannot
    // take out the audit record or the count above it.
    await addVotedRestaurant(
      db,
      event.params.userId,
      event.params.restaurantId
    );
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
    // Last, for the same reason as onVoteCreated above.
    await removeVotedRestaurant(
      db,
      event.params.userId,
      event.params.restaurantId
    );
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

  // Target validation. This callable is the only path that can create
  // a comment (firestore.rules denies direct client creates), so
  // nothing else is going to check these.
  //
  // An unchecked restaurantId writes to
  // restaurants/{garbage}/comments/{id}, where the parent document
  // does not exist. Every read path the app has starts from a
  // restaurant, so that comment is unreachable forever, and
  // onCommentCreated fires applyCommentCreated against a missing
  // document.
  const restaurantRef = db.collection("restaurants").doc(restaurantId);
  const restaurantSnap = await restaurantRef.get();
  if (!restaurantSnap.exists) {
    throw new HttpsError(
      "not-found",
      "That restaurant does not exist."
    );
  }

  if (parentId) {
    // The parent must exist, must live under this same restaurant,
    // and must itself be top level.
    //
    // The one-level rule is not a style preference, it is what the
    // read path can express. CommentRepository.getPage fetches
    // parentId == null and getReplies fetches parentId == commentId,
    // so nothing ever queries for the children of a reply. A reply to
    // a reply would be written successfully and then be permanently
    // invisible to every user including its author.
    const parentSnap = await restaurantRef
      .collection("comments")
      .doc(parentId)
      .get();

    if (!parentSnap.exists) {
      // Deliberately the same message whether the parent is missing
      // entirely or lives under a different restaurant. Distinguishing
      // them would confirm to a caller that a given comment id exists
      // somewhere, and the caller has no legitimate use for that.
      throw new HttpsError(
        "not-found",
        "That comment is no longer available."
      );
    }
    if (parentSnap.data()?.parentId) {
      throw new HttpsError(
        "invalid-argument",
        "You can only reply to a top level comment."
      );
    }
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

// APP CHECK MUST NEVER BE ENFORCED ON THIS FUNCTION.
//
// Its caller is the marketing site, not the app. site/index.html
// posts here with a plain browser fetch, and a browser has no App
// Attest or Play Integrity token to present. Enforcing App Check
// here breaks the vouchfood.com signup form silently: the form keeps
// submitting and every submission 401s.
//
// This is stated at the definition rather than only in
// docs/DECISIONS.md because "App Check is enforced" reads like a
// project-wide switch, and the person who reaches for it in six
// months will be reading this file, not that one.
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

      const checked = checkSignupInput({email, city, source}, EMAIL_RE);
      if (!checked.ok) {
        res.status(400).json({ok: false, error: checked.error});
        return;
      }

      // The IP allowance is spent before the waitlist read, so that
      // the number of Firestore operations one address can cause is
      // bounded rather than only the number of rows it can leave
      // behind. A request that never gets past validation costs no
      // Firestore operations at all and so is not counted.
      const ip = clientIpFrom(req);
      const attempt = await recordSignupAttempt(db, ip, new Date());
      if (!attempt.allowed) {
        logger.warn(
          `[waitlist] rate limited: ${ip ?? "unknown IP"} has used its ` +
          `${MAX_SIGNUPS_PER_IP_PER_DAY} signups today. If this is a real ` +
          "person behind carrier NAT, this log is the only evidence."
        );
        res.status(429).json({ok: false, error: "rate_limited"});
        return;
      }

      const normalized = checked.email;
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
        city: checked.city,
        source: checked.source,
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

// Optional on purpose. An unset secret reads as an empty string and
// leaves signature verification switched off, which is what lets this
// deploy safely before Andrew has generated it.
const revenueCatSigningSecret = defineSecret(
  "REVENUECAT_WEBHOOK_SIGNING_SECRET"
);

// APP CHECK MUST NEVER BE ENFORCED ON THIS FUNCTION.
//
// Its caller is RevenueCat's servers, not the app. There is no
// device and no attestation token, and there never will be.
//
// This one is worse than the waitlist if it is got wrong. Enforcing
// App Check here stops entitlement webhooks arriving, so users pay
// and never receive the tier they paid for, and the failure is
// invisible from inside the app: the purchase succeeds at the store
// and the claim never lands.
//
// Authentication here is the shared bearer secret checked by
// isValidAuth below, plus the signature verification tracked as
// finding 5. Not App Check.
export const onRevenueCatWebhook = onRequest(
  {
    cors: false,
    secrets: [revenueCatWebhookSecret, revenueCatSigningSecret],
  },
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

    // Second layer, and inert until the signing secret exists.
    //
    // Held deliberately rather than shipped enabled. This is the only
    // piece of finding 5 that can reject live traffic if it is
    // misconfigured, and the failure is silent from inside the app: a
    // rejected webhook means subscribers stop being upgraded and
    // nothing in the client can tell. So it arrives on its own, after
    // the secret is set and after REVENUECAT_SIGNATURE_HEADER has been
    // confirmed against RevenueCat's documentation.
    //
    // Skipping when the secret is unset is the whole hold mechanism.
    // It is logged at warn every time, so "we never turned it on" is
    // visible in the logs rather than remembered.
    const signingSecret = revenueCatSigningSecret.value();
    if (signingSecret) {
      const signature = req.headers[REVENUECAT_SIGNATURE_HEADER];
      const provided = Array.isArray(signature) ? signature[0] : signature;
      if (!verifyWebhookSignature(req.rawBody, provided, signingSecret)) {
        logger.error(
          "[webhook] rejected: signature did not verify. If this is " +
          "every request rather than one, check " +
          "REVENUECAT_SIGNATURE_HEADER against RevenueCat's docs " +
          "before assuming an attack."
        );
        res.status(401).json({error: "bad_signature"});
        return;
      }
    } else {
      logger.warn(
        "[webhook] signature verification is OFF: " +
        "REVENUECAT_WEBHOOK_SIGNING_SECRET is not set. The bearer " +
        "secret is the only thing authenticating this request."
      );
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

      const result = await processWebhookEvent(db, event);
      logger.info(
        `[webhook] ${event.type}: uid=${result.uid}, ` +
        `tier=${result.tier}, ` +
        `claimSet=${
          result.notApplied ?
            `no (${result.notApplied})` :
            result.skipped ? "skipped (user not found)" : "yes"
        }`
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

// ---------------------------------------------------------------------------
// 8. reconcileMembership
//    HTTPS callable. Asks RevenueCat directly what this user is
//    entitled to and repairs the claim from the answer.
//
//    The webhook is the only thing that has ever set a membership
//    claim, so a webhook that is never delivered leaves a paying user
//    locked out with no way back. membership_provider.dart already
//    detects that state precisely, calling it awaiting confirmation,
//    and its retry button could only ever re-read the same claim that
//    was never going to change. This is what that button now calls.
//
//    The uid comes from the auth context and never from the payload.
//    A client that could name the user would be able to ask for
//    somebody else's tier to be recomputed, which is a lever on an
//    account it does not own.
// ---------------------------------------------------------------------------

const revenueCatRestApiKey = defineSecret("REVENUECAT_REST_API_KEY");

/** Reconciliations one user may request in a UTC day. */
export const MAX_RECONCILES_PER_DAY = 5;

export const reconcileMembership = onCall(
  {secrets: [revenueCatRestApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to refresh your membership."
      );
    }

    const uid = request.auth.uid;
    const now = new Date();
    const dateKey = now.toISOString().split("T")[0];

    // A per user daily cap, in a transaction, for the same reason
    // submitSuggestion has one: this endpoint makes an outbound call
    // to a third party's API on demand, and an unbounded button is a
    // way to spend RevenueCat's rate limit from a phone.
    const counterRef = db
      .collection("users")
      .doc(uid)
      .collection("reconcileCounts")
      .doc(dateKey);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const count = (snap.data()?.count as number) ?? 0;
      if (count >= MAX_RECONCILES_PER_DAY) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many refresh attempts today. Try again tomorrow, or " +
          "contact support if your purchase still is not showing."
        );
      }
      tx.set(counterRef, {count: count + 1, date: dateKey}, {merge: true});
    });

    try {
      const result = await reconcileMembershipFor(
        db,
        uid,
        revenueCatRestApiKey.value(),
        now,
        globalThis.fetch as unknown as FetchLike
      );
      return {tier: result.tier, changed: result.changed};
    } catch (err) {
      if (err instanceof EntitlementLookupError) {
        // Deliberately not "you have no subscription". Not knowing and
        // knowing there is nothing are different answers, and only one
        // of them is safe to act on.
        logger.error(`[reconcile] lookup failed for uid=${uid}`, {
          error: err.message,
        });
        throw new HttpsError(
          "unavailable",
          "Could not reach the subscription service. Please try again."
        );
      }
      throw err;
    }
  }
);
