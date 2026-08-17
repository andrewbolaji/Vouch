/**
 * Pins the state of finding 5's two deploy switches.
 *
 * This suite exists to make flipping one a deliberate act. Both are
 * off, so `reconcileMembership` has no REvenueCat key attached and
 * must refuse rather than answer. When Andrew creates the secret and
 * flips `RECONCILE_ENABLED`, this test fails, which is the intended
 * behaviour: the commit that turns the feature on should have to say
 * so here too.
 *
 * Own file because importing index.ts runs its module-scope
 * initializeApp(), the same reason submit_comment.test.ts and
 * waitlist.test.ts are separate.
 */

import {getApps, deleteApp} from "firebase-admin/app";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

// eslint-disable-next-line import/first
import {reconcileMembership} from "./index";

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/**
 * Builds a callable request with an auth context.
 *
 * @param {string} uid The caller's uid.
 * @return {object} A request shaped like CallableRequest.
 */
function requestFor(uid: string) {
  return {
    data: {},
    auth: {uid, token: {uid} as Record<string, unknown>},
    rawRequest: {headers: {}},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

describe("reconcileMembership while its switch is off", () => {
  test("refuses with failed-precondition rather than answering free",
    async () => {
      // The distinction revenuecat_api.ts is built around, enforced at
      // the entry point too: not knowing and knowing there is nothing
      // are different answers, and only one of them is safe to act on.
      // A disabled endpoint that returned "free" would downgrade every
      // caller.
      await expect(reconcileMembership.run(requestFor("switch-1")))
        .rejects.toMatchObject({code: "failed-precondition"});
    });

  test("refuses before checking auth, so it cannot leak that it is live",
    async () => {
      // Unauthenticated callers get the same answer as authenticated
      // ones while the feature is off. Ordering asserted rather than
      // assumed, because the two guards are one line apart and easy to
      // swap by accident later.
      const anonymous = {data: {}, rawRequest: {headers: {}}};
      await expect(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        reconcileMembership.run(anonymous as any)
      ).rejects.toMatchObject({code: "failed-precondition"});
    });
});
