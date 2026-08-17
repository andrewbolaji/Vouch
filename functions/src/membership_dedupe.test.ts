/**
 * Finding 5, part 1: exactly-once, and never-backwards.
 *
 * Own file rather than more suites in index.test.ts, which is already
 * 2,000 lines and initialises its own app. These need Auth as well as
 * Firestore, because the thing being protected is the custom claim.
 */

import {initializeApp, getApps, deleteApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

if (getApps().length === 0) {
  initializeApp({projectId: "vouch-test"});
}

// eslint-disable-next-line import/first
import {
  processWebhookEvent,
  WebhookProcessingBusyError,
  WEBHOOK_EVENTS_COLLECTION,
  MEMBERSHIP_STATE_COLLECTION,
} from "./membership_webhook";

const db = getFirestore();
const auth = getAuth();

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/**
 * Deletes every top-level document and everything under it.
 */
async function clearFirestore() {
  const collections = await db.listCollections();
  for (const col of collections) {
    const docs = await col.listDocuments();
    for (const d of docs) {
      await db.recursiveDelete(d);
    }
  }
}

/**
 * Creates an Auth user so the claim write has somewhere to land.
 *
 * @param {string} uid The user id to create.
 */
async function createUser(uid: string) {
  try {
    await auth.deleteUser(uid);
  } catch {
    // Not there, which is the normal case.
  }
  await auth.createUser({uid, email: `${uid}@example.com`});
}

/**
 * Reads the membershipTier custom claim currently on a user.
 *
 * @param {string} uid The user id.
 * @return {Promise<string|undefined>} The claim, if set.
 */
async function claimFor(uid: string): Promise<string | undefined> {
  const user = await auth.getUser(uid);
  return (user.customClaims ?? {}).membershipTier as string | undefined;
}

const now = new Date("2026-08-17T12:00:00Z");

describe("processWebhookEvent: duplicates", () => {
  beforeEach(async () => {
    await clearFirestore();
    await createUser("dedupe-1");
  });

  test("the same event id is applied once and ignored after", async () => {
    const event = {
      id: "evt-1",
      type: "INITIAL_PURCHASE",
      app_user_id: "dedupe-1",
      entitlement_ids: ["locals_pass"],
      event_timestamp_ms: 1_000,
    };

    const first = await processWebhookEvent(db, event, now);
    const second = await processWebhookEvent(db, event, now);

    expect(first.notApplied).toBeUndefined();
    expect(second.notApplied).toBe("duplicate");
    expect(await claimFor("dedupe-1")).toBe("localsPass");
  });

  test("a record is kept, with an expiry for the TTL policy", async () => {
    await processWebhookEvent(db, {
      id: "evt-2",
      type: "INITIAL_PURCHASE",
      app_user_id: "dedupe-1",
      entitlement_ids: ["city_insider"],
      event_timestamp_ms: 2_000,
    }, now);

    const doc = await db
      .collection(WEBHOOK_EVENTS_COLLECTION)
      .doc("evt-2")
      .get();

    expect(doc.data()?.status).toBe("done");
    expect(doc.data()?.uid).toBe("dedupe-1");
    expect(doc.data()?.tier).toBe("cityInsider");
    // One document per event forever is a storage leak with a slow
    // fuse, and the TTL policy cannot delete what does not carry the
    // field.
    const expiresAt = doc.data()?.expiresAt as {toDate: () => Date};
    expect(expiresAt.toDate().getTime()).toBeGreaterThan(now.getTime());
  });

  test("an event with no id is processed rather than refused", async () => {
    // Deliberate direction of failure. Refusing a real event over a
    // missing optional field costs a paying user their tier.
    const result = await processWebhookEvent(db, {
      type: "INITIAL_PURCHASE",
      app_user_id: "dedupe-1",
      entitlement_ids: ["locals_pass"],
    }, now);

    expect(result.notApplied).toBeUndefined();
    expect(await claimFor("dedupe-1")).toBe("localsPass");
  });

  test("an interrupted apply is retried rather than skipped", async () => {
    // A record left at "claimed" means an earlier attempt died between
    // claiming the event and applying it. That is precisely the case a
    // retry exists for, so it must not be treated as a duplicate.
    await db.collection(WEBHOOK_EVENTS_COLLECTION).doc("evt-3").set({
      eventId: "evt-3",
      uid: "dedupe-1",
      type: "INITIAL_PURCHASE",
      status: "claimed",
    });

    const result = await processWebhookEvent(db, {
      id: "evt-3",
      type: "INITIAL_PURCHASE",
      app_user_id: "dedupe-1",
      entitlement_ids: ["locals_pass"],
      event_timestamp_ms: 3_000,
    }, now);

    expect(result.notApplied).toBeUndefined();
    expect(await claimFor("dedupe-1")).toBe("localsPass");
  });

  test("an expired processing lease does not block recovery", async () => {
    await db.collection(WEBHOOK_EVENTS_COLLECTION).doc("evt-expired").set({
      eventId: "evt-expired",
      uid: "dedupe-1",
      type: "INITIAL_PURCHASE",
      status: "claimed",
    });
    await db.collection(MEMBERSHIP_STATE_COLLECTION).doc("dedupe-1").set({
      uid: "dedupe-1",
      processingEventId: "evt-abandoned",
      processingToken: "abandoned-token",
      processingLeaseUntil: Timestamp.fromDate(
        new Date(now.getTime() - 1)
      ),
    });

    const result = await processWebhookEvent(db, {
      id: "evt-expired",
      type: "INITIAL_PURCHASE",
      app_user_id: "dedupe-1",
      entitlement_ids: ["city_insider"],
      event_timestamp_ms: 4_000,
    }, now);

    expect(result.notApplied).toBeUndefined();
    expect(await claimFor("dedupe-1")).toBe("cityInsider");
  });
});

describe("processWebhookEvent: the retry-after-resubscribe case", () => {
  beforeEach(async () => {
    await clearFirestore();
    await createUser("order-1");
  });

  test("a stale EXPIRATION does not downgrade a resubscribed user",
    async () => {
      // The sequence that motivates the whole guard, in order of
      // arrival rather than in order of occurrence:
      //   t=1000  EXPIRATION   fails, RevenueCat will retry it
      //   t=2000  PURCHASE     arrives and is applied
      //   t=1000  EXPIRATION   the retry, arriving late
      await processWebhookEvent(db, {
        id: "evt-purchase",
        type: "INITIAL_PURCHASE",
        app_user_id: "order-1",
        entitlement_ids: ["locals_pass"],
        event_timestamp_ms: 2_000,
      }, now);

      expect(await claimFor("order-1")).toBe("localsPass");

      const late = await processWebhookEvent(db, {
        id: "evt-expiration",
        type: "EXPIRATION",
        app_user_id: "order-1",
        entitlement_ids: [],
        event_timestamp_ms: 1_000,
      }, now);

      expect(late.notApplied).toBe("stale");
      // The assertion that matters. Deduplication alone would not have
      // caught this: the two events are genuinely different events.
      expect(await claimFor("order-1")).toBe("localsPass");
      const user = await db.collection("users").doc("order-1").get();
      expect(user.data()?.membershipTier).toBe("localsPass");
    });

  test("a newer EXPIRATION still downgrades, because it should",
    async () => {
      // The control. A guard that refused every EXPIRATION would pass
      // the test above and be catastrophically wrong.
      await processWebhookEvent(db, {
        id: "evt-p2",
        type: "INITIAL_PURCHASE",
        app_user_id: "order-1",
        entitlement_ids: ["locals_pass"],
        event_timestamp_ms: 2_000,
      }, now);

      const later = await processWebhookEvent(db, {
        id: "evt-e2",
        type: "EXPIRATION",
        app_user_id: "order-1",
        entitlement_ids: [],
        event_timestamp_ms: 5_000,
      }, now);

      expect(later.notApplied).toBeUndefined();
      expect(await claimFor("order-1")).toBe("free");
    });

  test("an older in-flight event cannot overwrite a newer event",
    async () => {
      const authInstance = getAuth();
      const originalSetClaims = authInstance.setCustomUserClaims.bind(
        authInstance
      );
      let releaseOlder!: () => void;
      let signalOlderStarted!: () => void;
      const olderBlocked = new Promise<void>((resolve) => {
        releaseOlder = resolve;
      });
      const olderStarted = new Promise<void>((resolve) => {
        signalOlderStarted = resolve;
      });

      const setClaims = jest.spyOn(authInstance, "setCustomUserClaims")
        .mockImplementation(async (uid, claims) => {
          const tier = (claims as {membershipTier?: string} | null)
            ?.membershipTier;
          if (tier === "free") {
            signalOlderStarted();
            await olderBlocked;
          }
          return originalSetClaims(uid, claims);
        });

      try {
        const older = processWebhookEvent(db, {
          id: "evt-concurrent-expiration",
          type: "EXPIRATION",
          app_user_id: "order-1",
          entitlement_ids: [],
          event_timestamp_ms: 1_000,
        }, now);

        await olderStarted;
        const newer = processWebhookEvent(db, {
          id: "evt-concurrent-purchase",
          type: "INITIAL_PURCHASE",
          app_user_id: "order-1",
          entitlement_ids: ["locals_pass"],
          event_timestamp_ms: 2_000,
        }, now);

        await expect(newer).rejects.toBeInstanceOf(
          WebhookProcessingBusyError
        );

        releaseOlder();
        await older;

        // RevenueCat retries the 500 response after the older invocation
        // releases the per-user lease. The newer event then applies.
        await processWebhookEvent(db, {
          id: "evt-concurrent-purchase",
          type: "INITIAL_PURCHASE",
          app_user_id: "order-1",
          entitlement_ids: ["locals_pass"],
          event_timestamp_ms: 2_000,
        }, now);

        expect(await claimFor("order-1")).toBe("localsPass");
        const user = await db.collection("users").doc("order-1").get();
        expect(user.data()?.membershipTier).toBe("localsPass");
      } finally {
        releaseOlder();
        setClaims.mockRestore();
      }
    });

  test("the watermark is the newest applied, and is server-only",
    async () => {
      await processWebhookEvent(db, {
        id: "evt-w1",
        type: "INITIAL_PURCHASE",
        app_user_id: "order-1",
        entitlement_ids: ["locals_pass"],
        event_timestamp_ms: 4_000,
      }, now);

      const state = await db
        .collection(MEMBERSHIP_STATE_COLLECTION)
        .doc("order-1")
        .get();
      expect(state.data()?.lastEventTimestampMs).toBe(4_000);

      // Not on users/{uid}, which the owner can write. A client that
      // could rewind its own watermark could replay an old downgrade
      // onto itself, and more to the point a security-relevant value
      // does not belong in a client-writable document.
      const user = await db.collection("users").doc("order-1").get();
      expect(user.data()?.lastEventTimestampMs).toBeUndefined();
    });

  test("an event with no timestamp is applied, not gambled on",
    async () => {
      // Without a timestamp there is nothing to compare, so the
      // ordering guard cannot express an opinion. Applying is the
      // right default for the same reason as the missing id: the
      // other direction costs a real user their tier.
      await processWebhookEvent(db, {
        id: "evt-t1",
        type: "INITIAL_PURCHASE",
        app_user_id: "order-1",
        entitlement_ids: ["locals_pass"],
        event_timestamp_ms: 9_000,
      }, now);

      const result = await processWebhookEvent(db, {
        id: "evt-t2",
        type: "INITIAL_PURCHASE",
        app_user_id: "order-1",
        entitlement_ids: ["city_insider"],
      }, now);

      expect(result.notApplied).toBeUndefined();
      expect(await claimFor("order-1")).toBe("cityInsider");
      // And it does not move the watermark backwards or forwards,
      // because it does not know where it is.
      const state = await db
        .collection(MEMBERSHIP_STATE_COLLECTION)
        .doc("order-1")
        .get();
      expect(state.data()?.lastEventTimestampMs).toBe(9_000);
    });
});
