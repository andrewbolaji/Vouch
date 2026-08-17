/**
 * Finding 5, part 2: reading entitlements back from RevenueCat.
 *
 * The parse has its own suite because it is the part most likely to
 * be wrong: it encodes an assumption about a third party's payload
 * shape, and the cost of that assumption failing quietly is a paying
 * subscriber downgraded to free. Every uncertain path is asserted to
 * throw rather than to return an empty list.
 */

import {initializeApp, getApps, deleteApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

if (getApps().length === 0) {
  initializeApp({projectId: "vouch-test"});
}

// eslint-disable-next-line import/first
import {
  activeEntitlementIdsFrom,
  fetchActiveEntitlements,
  reconcileMembershipFor,
  EntitlementLookupError,
  RC_API_BASE,
  FetchLike,
} from "./revenuecat_api";

const db = getFirestore();
const auth = getAuth();
const now = new Date("2026-08-17T12:00:00Z");

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/**
 * A fetch double that answers with one canned response.
 *
 * @param {object} opts status and body to answer with.
 * @return {object} the fetch double plus the calls it recorded.
 */
function fetchStub(opts: {status: number; body?: unknown; throws?: boolean}) {
  const calls: {url: string; headers: Record<string, string>}[] = [];
  const doFetch: FetchLike = async (url, init) => {
    calls.push({url, headers: init.headers});
    if (opts.throws) throw new Error("network down");
    return {
      status: opts.status,
      json: async () => {
        if (opts.body === undefined) throw new Error("not json");
        return opts.body;
      },
      text: async () => JSON.stringify(opts.body ?? null),
    };
  };
  return {doFetch, calls};
}

describe("activeEntitlementIdsFrom", () => {
  test("a future expiry is active, a past one is not", () => {
    const ids = activeEntitlementIdsFrom({
      subscriber: {
        entitlements: {
          locals_pass: {expires_date: "2026-09-01T00:00:00Z"},
          city_insider: {expires_date: "2026-01-01T00:00:00Z"},
        },
      },
    }, now);

    expect(ids).toEqual(["locals_pass"]);
  });

  test("a null expiry is a lifetime grant, not an expired one", () => {
    const ids = activeEntitlementIdsFrom({
      subscriber: {entitlements: {city_insider: {expires_date: null}}},
    }, now);

    expect(ids).toEqual(["city_insider"]);
  });

  test("a running grace period keeps the entitlement active", () => {
    // The window where RevenueCat is retrying a card. Treating it as
    // expired revokes access from somebody whose payment is simply
    // being retried, which is the least forgivable moment to do it.
    const ids = activeEntitlementIdsFrom({
      subscriber: {
        entitlements: {
          locals_pass: {
            expires_date: "2026-08-15T00:00:00Z",
            grace_period_expires_date: "2026-08-20T00:00:00Z",
          },
        },
      },
    }, now);

    expect(ids).toEqual(["locals_pass"]);
  });

  test("a subscriber who bought nothing has no entitlements", () => {
    expect(activeEntitlementIdsFrom({subscriber: {}}, now)).toEqual([]);
    expect(
      activeEntitlementIdsFrom({subscriber: {entitlements: {}}}, now)
    ).toEqual([]);
  });

  test("a shape it does not recognise throws, and never reads as empty",
    () => {
      // The rule this module exists to hold. An empty array is a real
      // answer meaning "pays for nothing", and a parse failure must
      // never be able to impersonate it, because the two produce
      // opposite outcomes for a paying user.
      expect(() => activeEntitlementIdsFrom({}, now))
        .toThrow(EntitlementLookupError);
      expect(() => activeEntitlementIdsFrom(
        {subscriber: {entitlements: [] as never}}, now
      )).toThrow(EntitlementLookupError);
      expect(() => activeEntitlementIdsFrom(
        {subscriber: {entitlements: {locals_pass: null as never}}}, now
      )).toThrow(EntitlementLookupError);
      expect(() => activeEntitlementIdsFrom(
        {subscriber: {entitlements: {p: {expires_date: "not a date"}}}}, now
      )).toThrow(EntitlementLookupError);
    });
});

describe("fetchActiveEntitlements", () => {
  test("calls the subscriber endpoint with the secret key", async () => {
    const {doFetch, calls} = fetchStub({
      status: 200,
      body: {subscriber: {entitlements: {}}},
    });

    await fetchActiveEntitlements("uid-1", "sk_test", now, doFetch);

    expect(calls[0].url).toBe(`${RC_API_BASE}/subscribers/uid-1`);
    expect(calls[0].headers.Authorization).toBe("Bearer sk_test");
  });

  test("a uid needing escaping does not break the path", async () => {
    const {doFetch, calls} = fetchStub({
      status: 200,
      body: {subscriber: {entitlements: {}}},
    });

    await fetchActiveEntitlements("uid/../admin", "sk", now, doFetch);

    expect(calls[0].url).toBe(`${RC_API_BASE}/subscribers/uid%2F..%2Fadmin`);
  });

  test("404 means they bought nothing, which is an answer", async () => {
    const {doFetch} = fetchStub({status: 404});
    await expect(fetchActiveEntitlements("uid-1", "sk", now, doFetch))
      .resolves.toEqual([]);
  });

  test("every other failure throws rather than answering empty",
    async () => {
      for (const status of [401, 429, 500, 503]) {
        const {doFetch} = fetchStub({status});
        await expect(fetchActiveEntitlements("uid-1", "sk", now, doFetch))
          .rejects.toThrow(EntitlementLookupError);
      }

      const dead = fetchStub({status: 200, throws: true});
      await expect(fetchActiveEntitlements("uid-1", "sk", now, dead.doFetch))
        .rejects.toThrow(EntitlementLookupError);

      const garbage = fetchStub({status: 200});
      await expect(
        fetchActiveEntitlements("uid-1", "sk", now, garbage.doFetch)
      ).rejects.toThrow(EntitlementLookupError);
    });
});

describe("reconcileMembershipFor", () => {
  beforeEach(async () => {
    try {
      await auth.deleteUser("recon-1");
    } catch {
      // Not there, which is the normal case.
    }
    await auth.createUser({uid: "recon-1", email: "recon-1@example.com"});
    await db.collection("users").doc("recon-1").delete();
  });

  test("repairs a claim the webhook never set", async () => {
    // The whole point. This user paid, the webhook was never
    // delivered, and before this existed the app's retry button could
    // only re-read the claim that was never going to change.
    const {doFetch} = fetchStub({
      status: 200,
      body: {
        subscriber: {
          entitlements: {locals_pass: {expires_date: "2026-12-01T00:00:00Z"}},
        },
      },
    });

    const result = await reconcileMembershipFor(
      db, "recon-1", "sk", now, doFetch
    );

    expect(result).toEqual({tier: "localsPass", changed: true});
    const user = await auth.getUser("recon-1");
    expect(user.customClaims?.membershipTier).toBe("localsPass");
    const doc = await db.collection("users").doc("recon-1").get();
    expect(doc.data()?.membershipTier).toBe("localsPass");
  });

  test("reports changed false when it was already right", async () => {
    await auth.setCustomUserClaims("recon-1", {membershipTier: "cityInsider"});
    const {doFetch} = fetchStub({
      status: 200,
      body: {subscriber: {entitlements: {city_insider: {expires_date: null}}}},
    });

    const result = await reconcileMembershipFor(
      db, "recon-1", "sk", now, doFetch
    );

    expect(result).toEqual({tier: "cityInsider", changed: false});
  });

  test("an expired subscription does downgrade, because it should",
    async () => {
      // The control for the rule above. "Never downgrade on failure"
      // must not turn into "never downgrade", or a cancelled
      // subscriber keeps paid content forever.
      await auth.setCustomUserClaims("recon-1", {
        membershipTier: "localsPass",
      });
      const {doFetch} = fetchStub({
        status: 200,
        body: {
          subscriber: {
            entitlements: {
              locals_pass: {expires_date: "2026-01-01T00:00:00Z"},
            },
          },
        },
      });

      const result = await reconcileMembershipFor(
        db, "recon-1", "sk", now, doFetch
      );

      expect(result).toEqual({tier: "free", changed: true});
      const user = await auth.getUser("recon-1");
      expect(user.customClaims?.membershipTier).toBe("free");
    });

  test("a failed lookup leaves the existing claim untouched", async () => {
    await auth.setCustomUserClaims("recon-1", {membershipTier: "localsPass"});
    const {doFetch} = fetchStub({status: 500});

    await expect(
      reconcileMembershipFor(db, "recon-1", "sk", now, doFetch)
    ).rejects.toThrow(EntitlementLookupError);

    const user = await auth.getUser("recon-1");
    expect(user.customClaims?.membershipTier).toBe("localsPass");
  });
});
