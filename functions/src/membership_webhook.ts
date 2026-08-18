/**
 * RevenueCat webhook handler for membership tier management.
 *
 * Pure logic extracted for testability. The HTTP endpoint in
 * index.ts delegates here after validating the auth header.
 */

import {createHmac, timingSafeEqual} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {Firestore, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export interface RevenueCatWebhookEvent {
  type: string;
  app_user_id: string;
  product_id?: string;
  entitlement_ids?: string[];
  /** RevenueCat's own id for this event. Used for deduplication. */
  id?: string;
  /** When RevenueCat says the event happened, not when it arrived. */
  event_timestamp_ms?: number;
}

/** Processed webhook events, one document per RevenueCat event id. */
export const WEBHOOK_EVENTS_COLLECTION = "webhookEvents";

/** Per user watermark of the newest event actually applied. */
export const MEMBERSHIP_STATE_COLLECTION = "membershipState";

/**
 * How long a processed-event record is kept.
 *
 * Only needs to outlive RevenueCat's retry window by a comfortable
 * margin, since its whole job is to recognise a retry. 30 days is
 * that margin. The field does nothing on its own: Firestore only acts
 * on it where a TTL policy exists for the collection group. That
 * policy was enabled and verified ACTIVE on 2026-08-17, and the
 * command is recorded in docs/DECISIONS.md so a new environment can
 * be brought to the same state.
 */
export const WEBHOOK_EVENT_TTL_DAYS = 30;

/**
 * Maps a set of RevenueCat entitlement IDs to the Firestore
 * membershipTier claim value. City Insider is a superset of
 * Locals Pass, so it takes priority.
 *
 * @param {string[]} ids - Active entitlement identifiers.
 * @return {string} The resolved membership tier.
 */
export function tierFromEntitlements(ids: string[]): string {
  if (ids.includes("city_insider")) return "cityInsider";
  if (ids.includes("locals_pass")) return "localsPass";
  return "free";
}

/**
 * Derives the target tier from a RevenueCat webhook event.
 *
 * EXPIRATION always sets tier to free (all entitlements expired).
 * All other events derive tier from the active entitlement_ids.
 *
 * @param {RevenueCatWebhookEvent} event - The webhook event.
 * @return {string} The resolved membership tier.
 */
export function tierFromEvent(event: RevenueCatWebhookEvent): string {
  if (event.type === "EXPIRATION") return "free";
  return tierFromEntitlements(event.entitlement_ids ?? []);
}

/**
 * Validates the webhook Authorization header against the stored
 * secret. RevenueCat sends: Authorization: Bearer <secret>
 *
 * This is the first of two layers and remains the only one in force
 * until REVENUECAT_WEBHOOK_SIGNING_SECRET is set, at which point
 * verifyWebhookSignature below runs as well. An earlier version of
 * this comment said RevenueCat does not sign webhooks and that the
 * shared secret was the only mechanism available; that was the state
 * of the integration rather than a fact about RevenueCat, and finding
 * 5 is the correction.
 *
 * A shared secret in a header is replayable and is only as good as
 * the transport. A signature over the body is not, which is why the
 * second layer is worth having even though this one stays.
 *
 * The comparison itself uses timingSafeEqual rather than
 * ===, so a byte-by-byte string compare can't leak how many leading
 * characters of the secret an attacker guessed correctly through
 * response timing.
 *
 * @param {string | undefined} header - The Authorization header.
 * @param {string} secret - The expected webhook secret.
 * @return {boolean} Whether the header is valid.
 */
export function isValidAuth(
  header: string | undefined,
  secret: string,
): boolean {
  if (!header) return false;
  const expected = `Bearer ${secret}`;
  const headerBuf = Buffer.from(header);
  const expectedBuf = Buffer.from(expected);
  // timingSafeEqual throws on mismatched lengths, so this check has
  // to happen first. It leaks length, not content, the same tradeoff
  // every constant-time string comparison makes.
  if (headerBuf.length !== expectedBuf.length) return false;
  return timingSafeEqual(headerBuf, expectedBuf);
}

/** The lower-case form Node uses for RevenueCat's signature header. */
export const REVENUECAT_SIGNATURE_HEADER =
  "x-revenuecat-webhook-signature";

/** RevenueCat's reference verifier uses a five-minute replay window. */
export const REVENUECAT_SIGNATURE_TOLERANCE_SECONDS = 300;

/**
 * Verifies RevenueCat's timestamped HMAC-SHA256 signature.
 *
 * RevenueCat sends `t=<unix timestamp>,v1=<hex digest>` and signs the
 * exact bytes of `<timestamp>.<raw body>`. The body is never
 * re-serialised: key order, unicode escaping and whitespace survive
 * the wire and do not survive a parse-and-reprint.
 *
 * The signed timestamp is also checked against a bounded tolerance.
 * Without that check, anybody who captured a legitimate request could
 * replay it forever with its still-valid signature.
 *
 * @param {Buffer} rawBody The exact bytes of the request body.
 * @param {string|undefined} header The signature header value.
 * @param {string} secret The shared signing secret.
 * @param {Date} now Reference time for the replay check.
 * @param {number} toleranceSeconds Maximum permitted clock skew.
 * @return {boolean} Whether the signature matches.
 */
export function verifyWebhookSignature(
  rawBody: Buffer | undefined,
  header: string | undefined,
  secret: string,
  now: Date = new Date(),
  toleranceSeconds: number = REVENUECAT_SIGNATURE_TOLERANCE_SECONDS,
): boolean {
  if (!rawBody || !header || !secret) return false;
  if (!Number.isFinite(toleranceSeconds) || toleranceSeconds < 0) {
    return false;
  }

  const parts = new Map<string, string>();
  for (const rawPart of header.split(",")) {
    const separator = rawPart.indexOf("=");
    if (separator <= 0) return false;

    const key = rawPart.slice(0, separator).trim();
    const value = rawPart.slice(separator + 1).trim();
    if (!key || !value || parts.has(key)) return false;
    parts.set(key, value);
  }

  const timestamp = parts.get("t");
  const provided = parts.get("v1");
  if (
    !timestamp ||
    !provided ||
    !/^\d+$/.test(timestamp) ||
    !/^[a-fA-F0-9]{64}$/.test(provided)
  ) {
    return false;
  }

  const timestampSeconds = Number(timestamp);
  const nowSeconds = now.getTime() / 1000;
  if (
    !Number.isSafeInteger(timestampSeconds) ||
    !Number.isFinite(nowSeconds)
  ) {
    return false;
  }

  const expected = createHmac("sha256", secret)
    .update(Buffer.from(`${timestamp}.`))
    .update(rawBody)
    .digest();
  const providedBuf = Buffer.from(provided, "hex");

  if (
    providedBuf.length !== expected.length ||
    !timingSafeEqual(providedBuf, expected)
  ) {
    return false;
  }

  return Math.abs(nowSeconds - timestampSeconds) <= toleranceSeconds;
}

/**
 * Processes a RevenueCat webhook event:
 * 1. Sets the membershipTier custom claim on the user's Auth token.
 * 2. Updates (or creates) the /users/{uid} Firestore doc with the
 *    tier.
 *
 * @param {Firestore} db - The Firestore instance.
 * @param {RevenueCatWebhookEvent} event - The webhook event.
 * @return {Promise} Resolved tier and uid.
 */
export async function handleWebhookEvent(
  db: Firestore,
  event: RevenueCatWebhookEvent,
): Promise<{tier: string; uid: string; skipped?: boolean}> {
  const uid = event.app_user_id;
  const tier = tierFromEvent(event);

  // 1. Set custom claim first (Firestore rules read this).
  try {
    await getAuth().setCustomUserClaims(uid, {membershipTier: tier});
  } catch (err: unknown) {
    // RevenueCat test events use fake user IDs that don't exist in
    // Firebase Auth. Acknowledge gracefully so RC doesn't retry.
    if (
      err !== null &&
      typeof err === "object" &&
      "code" in err &&
      (err as {code: string}).code === "auth/user-not-found"
    ) {
      logger.warn(
        `User not found in Auth, skipping: uid=${uid}, tier=${tier}`
      );
      return {tier, uid, skipped: true};
    }
    throw err;
  }
  logger.info(`Set membershipTier claim: uid=${uid}, tier=${tier}`);

  // 2. Update /users/{uid} doc. merge: true creates the doc if it
  //    does not exist (handles brand-new users gracefully).
  await db.collection("users").doc(uid).set(
    {membershipTier: tier},
    {merge: true},
  );

  return {tier, uid};
}

/** Why an event was not applied, when it was not. */
export type SkipReason = "duplicate" | "stale";

export interface ProcessResult {
  tier: string;
  uid: string;
  skipped?: boolean;
  notApplied?: SkipReason;
}

/**
 * Processes an event exactly once, and never applies an older event
 * over a newer one.
 *
 * Two guards, and the second is the one that matters.
 *
 * **Duplicate.** RevenueCat retries a webhook it did not get a 2xx
 * for, and Cloud Functions can deliver twice on its own. Both writes
 * this handler performs are idempotent today, so a plain replay is
 * harmless, and the record is kept anyway because it is the audit
 * trail for a subscription pipeline that currently has none, and
 * because "the writes happen to be idempotent" is a property of
 * today's handler rather than a guarantee about tomorrow's.
 *
 * **Stale.** This is the failure worth preventing. Deduplication
 * alone does not prevent it, because the two events are genuinely
 * different events. If an EXPIRATION fails and RevenueCat retries it
 * thirty minutes later, and the user resubscribes in between, the
 * retried EXPIRATION arrives after the PURCHASE and sets a paying
 * user back to free. Nothing in the app would ever correct it: the
 * client detects "paid but not claimed" and shows a pending state
 * that only the webhook can clear. So an event older than the newest
 * one already applied for that user is recorded and not applied.
 *
 * The event record is marked done only after the writes land. A
 * process that dies mid-apply leaves it "claimed", and a retry
 * reprocesses rather than skipping, because a claimed-but-unapplied
 * event is exactly the case a retry exists for.
 *
 * @param {Firestore} db Firestore instance.
 * @param {RevenueCatWebhookEvent} event The webhook event.
 * @param {Date} now Reference time, for the record's expiry.
 * @return {Promise<ProcessResult>} What happened, and why.
 */
export async function processWebhookEvent(
  db: Firestore,
  event: RevenueCatWebhookEvent,
  now: Date = new Date(),
): Promise<ProcessResult> {
  const uid = event.app_user_id;
  const eventId = event.id;
  const timestampMs = event.event_timestamp_ms;

  // An event with no id cannot be deduplicated. Processed rather than
  // refused: entitlements are revenue, and refusing a real event over
  // a missing optional field would fail in the direction that costs a
  // paying user their tier. It is logged so the assumption that
  // RevenueCat always sends one is checkable rather than assumed.
  if (!eventId) {
    logger.warn(
      `[webhook] event has no id, processing without dedupe: uid=${uid}, ` +
      `type=${event.type}`
    );
    return handleWebhookEvent(db, event);
  }

  const eventRef = db.collection(WEBHOOK_EVENTS_COLLECTION).doc(eventId);
  const stateRef = db.collection(MEMBERSHIP_STATE_COLLECTION).doc(uid);
  const expiresAt = Timestamp.fromDate(
    new Date(now.getTime() + WEBHOOK_EVENT_TTL_DAYS * 24 * 60 * 60 * 1000)
  );

  const decision = await db.runTransaction(async (tx) => {
    const [eventSnap, stateSnap] = await Promise.all([
      tx.get(eventRef),
      tx.get(stateRef),
    ]);

    if (eventSnap.data()?.status === "done") {
      return "duplicate" as const;
    }

    const applied = stateSnap.data()?.lastEventTimestampMs as
      number | undefined;
    if (
      typeof timestampMs === "number" &&
      typeof applied === "number" &&
      timestampMs < applied
    ) {
      tx.set(eventRef, {
        eventId,
        uid,
        type: event.type,
        eventTimestampMs: timestampMs,
        status: "skipped_stale",
        expiresAt,
      });
      return "stale" as const;
    }

    tx.set(eventRef, {
      eventId,
      uid,
      type: event.type,
      eventTimestampMs: timestampMs ?? null,
      status: "claimed",
      expiresAt,
    });
    return "apply" as const;
  });

  if (decision === "duplicate") {
    logger.info(
      `[webhook] duplicate event ignored: id=${eventId}, uid=${uid}`
    );
    return {tier: tierFromEvent(event), uid, notApplied: "duplicate"};
  }

  if (decision === "stale") {
    logger.warn(
      `[webhook] stale event ignored: id=${eventId}, uid=${uid}, ` +
      `type=${event.type}, event is older than the last one applied. ` +
      "This is the retry-after-resubscribe case, and applying it would " +
      "have downgraded a paying user."
    );
    return {tier: tierFromEvent(event), uid, notApplied: "stale"};
  }

  const result = await handleWebhookEvent(db, event);

  // Marked done only now, after the writes landed.
  const batch = db.batch();
  batch.set(eventRef, {status: "done", tier: result.tier}, {merge: true});
  if (typeof timestampMs === "number") {
    batch.set(
      stateRef,
      {uid, lastEventTimestampMs: timestampMs, tier: result.tier},
      {merge: true}
    );
  }
  await batch.commit();

  return result;
}
