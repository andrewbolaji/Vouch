/**
 * RevenueCat webhook handler for membership tier management.
 *
 * Pure logic extracted for testability. The HTTP endpoint in
 * index.ts delegates here after validating the auth header.
 */

import {getAuth} from "firebase-admin/auth";
import {Firestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export interface RevenueCatWebhookEvent {
  type: string;
  app_user_id: string;
  product_id?: string;
  entitlement_ids?: string[];
}

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
 * @param {string | undefined} header - The Authorization header.
 * @param {string} secret - The expected webhook secret.
 * @return {boolean} Whether the header is valid.
 */
export function isValidAuth(
  header: string | undefined,
  secret: string,
): boolean {
  if (!header) return false;
  return header === `Bearer ${secret}`;
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
