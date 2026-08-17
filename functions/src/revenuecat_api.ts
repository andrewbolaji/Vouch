/**
 * Reading entitlements back from RevenueCat. Finding 5, part 2.
 *
 * The webhook is the only thing that has ever set a membership claim,
 * and a webhook that is never delivered leaves the user paying and
 * locked out with no way back. `membership_provider.dart` detects the
 * state exactly ("paid according to RevenueCat, not according to the
 * claim") and shows a pending screen whose retry button re-reads the
 * same claim that will never change. This module is the missing
 * authority: ask RevenueCat directly, server side, and repair.
 *
 * The one rule that matters here: **a failure to read must never be
 * read as "no entitlements".** Downgrading a paying subscriber
 * because an HTTP call failed or a payload shape moved would be a
 * worse bug than the one being fixed, so every uncertain path throws
 * instead of returning an empty list.
 */

import {Firestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import {tierFromEntitlements} from "./membership_webhook";

/** RevenueCat's REST v1 base. */
export const RC_API_BASE = "https://api.revenuecat.com/v1";

/** Signals that entitlements could not be determined, at all. */
export class EntitlementLookupError extends Error {
  /**
   * @param {string} message Why the lookup could not be trusted.
   */
  constructor(message: string) {
    super(message);
    this.name = "EntitlementLookupError";
  }
}

/** The subset of the v1 subscriber payload this cares about. */
export interface RcEntitlement {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  product_identifier?: string;
}

export interface RcSubscriberResponse {
  subscriber?: {
    entitlements?: Record<string, RcEntitlement>;
  };
}

/**
 * The entitlement ids that are active right now.
 *
 * Active means no expiry (a lifetime grant), an expiry in the future,
 * or a grace period still running. Grace period counts because that
 * is precisely the window where RevenueCat is retrying a payment and
 * the subscriber is still entitled; treating it as expired would
 * revoke access from someone whose card is simply being retried.
 *
 * Throws rather than returning an empty array when the payload does
 * not have the expected shape. An empty array is a legitimate answer
 * meaning "this person pays for nothing", and a parse failure must
 * never be able to impersonate it.
 *
 * @param {RcSubscriberResponse} body The parsed response body.
 * @param {Date} now Reference time.
 * @return {string[]} Active entitlement identifiers.
 */
export function activeEntitlementIdsFrom(
  body: RcSubscriberResponse,
  now: Date
): string[] {
  const subscriber = body?.subscriber;
  if (!subscriber || typeof subscriber !== "object") {
    throw new EntitlementLookupError(
      "response has no subscriber object, shape may have changed"
    );
  }

  const entitlements = subscriber.entitlements;
  // Absent and empty are different from malformed. A subscriber who
  // has never bought anything legitimately has no entitlements key.
  if (entitlements === undefined || entitlements === null) return [];
  if (typeof entitlements !== "object" || Array.isArray(entitlements)) {
    throw new EntitlementLookupError(
      "entitlements is not an object, shape may have changed"
    );
  }

  const active: string[] = [];
  for (const [id, value] of Object.entries(entitlements)) {
    if (!value || typeof value !== "object") {
      throw new EntitlementLookupError(
        `entitlement ${id} is not an object, shape may have changed`
      );
    }
    const until = latestOf(
      value.expires_date ?? null,
      value.grace_period_expires_date ?? null
    );
    // A null expiry is a lifetime entitlement, not an expired one.
    if (until === null) {
      active.push(id);
      continue;
    }
    if (until.getTime() > now.getTime()) active.push(id);
  }
  return active;
}

/**
 * The later of two optional RFC 3339 timestamps, or null if either is
 * absent (absent means no limit).
 *
 * @param {string|null} a First timestamp.
 * @param {string|null} b Second timestamp.
 * @return {Date|null} The later date, or null for no limit.
 */
function latestOf(a: string | null, b: string | null): Date | null {
  if (a === null || b === null) {
    const single = a ?? b;
    if (single === null) return null;
    return parseOrThrow(single);
  }
  const da = parseOrThrow(a);
  const db2 = parseOrThrow(b);
  return da.getTime() >= db2.getTime() ? da : db2;
}

/**
 * Parses a timestamp, refusing to guess.
 *
 * @param {string} value The timestamp string.
 * @return {Date} The parsed date.
 */
function parseOrThrow(value: string): Date {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new EntitlementLookupError(`unparseable date: ${value}`);
  }
  return parsed;
}

/** Minimal shape of fetch, so tests can substitute one. */
export type FetchLike = (
  url: string,
  init: {method: string; headers: Record<string, string>}
) => Promise<{
  status: number;
  json: () => Promise<unknown>;
  text: () => Promise<string>;
}>;

/**
 * Asks RevenueCat what this user is actually entitled to.
 *
 * @param {string} uid The app user id, which is the Firebase uid.
 * @param {string} apiKey The RevenueCat REST secret key.
 * @param {Date} now Reference time.
 * @param {FetchLike} doFetch Injected for tests.
 * @return {Promise<string[]>} Active entitlement identifiers.
 */
export async function fetchActiveEntitlements(
  uid: string,
  apiKey: string,
  now: Date,
  doFetch: FetchLike
): Promise<string[]> {
  const url = `${RC_API_BASE}/subscribers/${encodeURIComponent(uid)}`;
  let response;
  try {
    response = await doFetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
    });
  } catch (err) {
    throw new EntitlementLookupError(
      `request failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  // 404 is the one non-200 that is an answer rather than a failure:
  // RevenueCat does not know this app user id, which means they have
  // bought nothing. Everything else is a failure and must not be
  // allowed to look like "entitled to nothing".
  if (response.status === 404) return [];
  if (response.status !== 200) {
    throw new EntitlementLookupError(
      `RevenueCat returned ${response.status}`
    );
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new EntitlementLookupError("response body was not JSON");
  }

  return activeEntitlementIdsFrom(body as RcSubscriberResponse, now);
}

/**
 * Repairs one user's tier from RevenueCat's own record.
 *
 * Sets the claim first, for the same reason the webhook does:
 * firestore.rules reads the claim, and the Firestore document is a
 * convenience copy.
 *
 * @param {Firestore} db Firestore instance.
 * @param {string} uid The Firebase uid, taken from the auth context.
 * @param {string} apiKey The RevenueCat REST secret key.
 * @param {Date} now Reference time.
 * @param {FetchLike} doFetch Injected for tests.
 * @return {Promise<object>} The tier now in force, and whether it moved.
 */
export async function reconcileMembershipFor(
  db: Firestore,
  uid: string,
  apiKey: string,
  now: Date,
  doFetch: FetchLike
): Promise<{tier: string; changed: boolean}> {
  const ids = await fetchActiveEntitlements(uid, apiKey, now, doFetch);
  const tier = tierFromEntitlements(ids);

  const before = (await getAuth().getUser(uid)).customClaims ?? {};
  const changed = before.membershipTier !== tier;

  await getAuth().setCustomUserClaims(uid, {membershipTier: tier});
  await db.collection("users").doc(uid).set(
    {membershipTier: tier},
    {merge: true}
  );

  if (changed) {
    logger.warn(
      `[reconcile] repaired uid=${uid}: claim was ` +
      `${String(before.membershipTier)}, RevenueCat says ${tier}. ` +
      "A webhook was missed or arrived out of order."
    );
  } else {
    logger.info(`[reconcile] uid=${uid} already correct at ${tier}`);
  }

  return {tier, changed};
}
