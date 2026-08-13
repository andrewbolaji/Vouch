/**
 * Tests for the vote audit trail (recordVoteCreated/recordVoteDeleted).
 *
 * Run with emulators:
 *   firebase emulators:exec --only firestore \
 *     'cd functions && npx jest --forceExit vote_audit.test.ts'
 *
 * In its own file for the same reason as submit_comment.test.ts: a
 * fresh module registry means its own initializeApp() call with no
 * effect on index.test.ts's suites.
 *
 * What is NOT tested here: the Firestore trigger wiring itself, or
 * that Cloud Functions retries actually reuse the same event.id on
 * redelivery. Both are Firebase infrastructure. The dedup test below
 * simulates a retry by calling the function twice with the same
 * eventId, which is the one thing our own code is responsible for.
 */

import {initializeApp, getApps, deleteApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {recordVoteCreated, recordVoteDeleted} from "./vote_audit";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

if (getApps().length === 0) {
  initializeApp({projectId: "vouch-test"});
}

const db = getFirestore();

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/** Clears all Firestore data between tests. */
async function clearFirestore() {
  const collections = await db.listCollections();
  for (const col of collections) {
    const docs = await col.listDocuments();
    for (const d of docs) {
      await d.delete();
    }
  }
}

describe("vote audit trail", () => {
  beforeEach(async () => {
    await clearFirestore();
    await db.collection("restaurants").doc("hou-1").set({
      id: "hou-1",
      cityId: "houston",
      name: "Turkey Leg Hut",
      rank: 1,
      voteCount: 0,
    });
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("a vote create writes exactly one event", async () => {
    await recordVoteCreated(db, "evt-create-1", "hou-1", "alice", 1);

    const snap = await db.collection("voteEvents").get();
    expect(snap.size).toBe(1);

    const data = snap.docs[0].data();
    expect(data.eventId).toBe("evt-create-1");
    expect(data.type).toBe("create");
    expect(data.userId).toBe("alice");
    expect(data.restaurantId).toBe("hou-1");
    expect(data.cityId).toBe("houston");
    expect(data.weight).toBe(1);
    expect(data.occurredAt).toBeDefined();
    expect(snap.docs[0].id).toBe("evt-create-1");
  });

  // eslint-disable-next-line max-len
  test("a create records the weight it was given, not a hardcoded 1", async () => {
    await recordVoteCreated(db, "evt-create-weighted", "hou-1", "alice", 3);

    const snap = await db
      .collection("voteEvents")
      .doc("evt-create-weighted")
      .get();
    expect(snap.data()?.weight).toBe(3);
  });

  // eslint-disable-next-line max-len
  test("a delete writes one event, captures voteCreatedAt and weight", async () => {
    const originalCreatedAt = Timestamp.now();

    await recordVoteDeleted(
      db,
      "evt-delete-1",
      "hou-1",
      "alice",
      originalCreatedAt,
      1
    );

    const snap = await db.collection("voteEvents").get();
    expect(snap.size).toBe(1);

    const data = snap.docs[0].data();
    expect(data.eventId).toBe("evt-delete-1");
    expect(data.type).toBe("delete");
    expect(data.userId).toBe("alice");
    expect(data.restaurantId).toBe("hou-1");
    expect(data.cityId).toBe("houston");
    expect(data.weight).toBe(1);
    expect(data.voteCreatedAt).toBeDefined();
    expect(data.voteCreatedAt.toMillis())
      .toBe(originalCreatedAt.toMillis());
  });

  test("a delete with no createdAt records voteCreatedAt null", async () => {
    await recordVoteDeleted(db, "evt-delete-2", "hou-1", "alice", null, 1);

    const snap = await db.collection("voteEvents").doc("evt-delete-2").get();
    expect(snap.data()?.voteCreatedAt).toBeNull();
  });

  test("a duplicate eventId does not produce two records", async () => {
    await recordVoteCreated(db, "evt-dup-1", "hou-1", "alice", 1);
    await recordVoteCreated(db, "evt-dup-1", "hou-1", "alice", 1);

    const snap = await db.collection("voteEvents").get();
    expect(snap.size).toBe(1);
  });

  test("an orphaned restaurantId still writes, cityId null", async () => {
    await recordVoteCreated(
      db,
      "evt-orphan-1",
      "nonexistent-restaurant",
      "alice",
      1
    );

    const snap = await db.collection("voteEvents").doc("evt-orphan-1").get();
    expect(snap.exists).toBe(true);
    expect(snap.data()?.cityId).toBeNull();
    expect(snap.data()?.restaurantId).toBe("nonexistent-restaurant");
  });
});
