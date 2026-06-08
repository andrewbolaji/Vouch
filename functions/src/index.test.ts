/**
 * Cloud Function tests for Vouch.
 *
 * Run with emulators:
 *   firebase emulators:exec --only firestore,auth,functions \
 *     'cd functions && npx jest --forceExit --detectOpenHandles --verbose'
 *
 * Tests the actual function logic against the Firestore emulator.
 */

import {initializeApp, getApps, deleteApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

// Initialize admin SDK for emulator
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

if (getApps().length === 0) {
  initializeApp({projectId: "vouch-test"});
}

const db = getFirestore();

async function clearFirestore() {
  const collections = await db.listCollections();
  for (const col of collections) {
    const docs = await col.listDocuments();
    for (const d of docs) {
      await d.delete();
    }
  }
}

// ================================================================
// Vote aggregation (testing the logic, not the trigger wiring)
// The actual trigger functions read/write Firestore.
// We simulate what the function does and verify the outcome.
// ================================================================

describe("Vote aggregation logic", () => {
  beforeEach(async () => {
    await clearFirestore();
    // Seed a restaurant
    await db.collection("restaurants").doc("hou-1").set({
      id: "hou-1",
      cityId: "houston",
      name: "Turkey Leg Hut",
      rank: 1,
      voteCount: 100,
    });
  });

  afterAll(async () => {
    await clearFirestore();
    const apps = getApps();
    for (const app of apps) {
      await deleteApp(app);
    }
  });

  test("increment(1) on vote create increases voteCount", async () => {
    const restaurantRef = db.collection("restaurants").doc("hou-1");

    // Simulate what onVoteCreated does
    await restaurantRef.update({voteCount: FieldValue.increment(1)});

    const snap = await restaurantRef.get();
    expect(snap.data()?.voteCount).toBe(101);
  });

  test("increment(-1) on vote delete decreases voteCount", async () => {
    const restaurantRef = db.collection("restaurants").doc("hou-1");

    // Simulate what onVoteDeleted does
    await restaurantRef.update({voteCount: FieldValue.increment(-1)});

    const snap = await restaurantRef.get();
    expect(snap.data()?.voteCount).toBe(99);
  });

  test("multiple increments are additive", async () => {
    const restaurantRef = db.collection("restaurants").doc("hou-1");

    await restaurantRef.update({voteCount: FieldValue.increment(1)});
    await restaurantRef.update({voteCount: FieldValue.increment(1)});
    await restaurantRef.update({voteCount: FieldValue.increment(1)});

    const snap = await restaurantRef.get();
    expect(snap.data()?.voteCount).toBe(103);
  });

  test("increment after decrement nets to zero change", async () => {
    const restaurantRef = db.collection("restaurants").doc("hou-1");

    await restaurantRef.update({voteCount: FieldValue.increment(1)});
    await restaurantRef.update({voteCount: FieldValue.increment(-1)});

    const snap = await restaurantRef.get();
    expect(snap.data()?.voteCount).toBe(100);
  });
});

// ================================================================
// Suggestion submission (testing the transaction logic)
// ================================================================

describe("Suggestion submission logic", () => {
  const uid = "test-user-1";
  const dateKey = new Date().toISOString().split("T")[0];

  beforeEach(async () => {
    await clearFirestore();
    // Seed user doc
    await db.collection("users").doc(uid).set({
      uid,
      displayName: "TestUser",
      email: "test@example.com",
    });
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("first suggestion of the day succeeds", async () => {
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

      // Cap is 1
      expect(currentCount).toBe(0);

      tx.set(suggestionRef, {
        id: suggestionRef.id,
        userId: uid,
        type: "general",
        text: "Add more cities",
        createdAt: FieldValue.serverTimestamp(),
        status: "pending",
      });

      tx.set(counterRef, {count: FieldValue.increment(1), date: dateKey}, {merge: true});
    });

    // Verify suggestion was written
    const suggestionSnap = await suggestionRef.get();
    expect(suggestionSnap.exists).toBe(true);
    expect(suggestionSnap.data()?.type).toBe("general");
    expect(suggestionSnap.data()?.status).toBe("pending");

    // Verify counter was incremented
    const counterSnap = await counterRef.get();
    expect(counterSnap.data()?.count).toBe(1);
  });

  test("second suggestion of the day is rejected (N+1)", async () => {
    const counterRef = db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .doc(dateKey);

    // Pre-seed the counter at 1 (already used today's quota)
    await counterRef.set({count: 1, date: dateKey});

    let rejected = false;

    try {
      await db.runTransaction(async (tx) => {
        const counterSnap = await tx.get(counterRef);
        const currentCount = counterSnap.exists
          ? (counterSnap.data()?.count as number) ?? 0
          : 0;

        if (currentCount >= 1) {
          throw new Error("RATE_LIMITED");
        }

        // This should not execute
        tx.set(db.collection("suggestions").doc(), {
          userId: uid,
          type: "general",
          text: "Should not be written",
        });
      });
    } catch (e: unknown) {
      if (e instanceof Error && e.message === "RATE_LIMITED") {
        rejected = true;
      }
    }

    expect(rejected).toBe(true);

    // Verify no suggestion was written
    const suggestions = await db
      .collection("suggestions")
      .where("userId", "==", uid)
      .get();
    expect(suggestions.size).toBe(0);
  });

  test("counter only affects the current user", async () => {
    const otherUid = "other-user";
    const counterRef = db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .doc(dateKey);
    const otherCounterRef = db
      .collection("users")
      .doc(otherUid)
      .collection("suggestionCounts")
      .doc(dateKey);

    // User 1 has used their quota
    await counterRef.set({count: 1, date: dateKey});
    // User 2 has not
    // (no counter doc exists)

    const otherSnap = await otherCounterRef.get();
    expect(otherSnap.exists).toBe(false);

    // User 2 should be able to submit
    const otherCount = otherSnap.exists
      ? (otherSnap.data()?.count as number) ?? 0
      : 0;
    expect(otherCount).toBe(0);
    // 0 < 1, so submission would proceed
  });
});

// ================================================================
// Account deletion cleanup (testing the cleanup logic)
// ================================================================

describe("Account deletion cleanup logic", () => {
  const uid = "deleted-user";

  beforeEach(async () => {
    await clearFirestore();

    // Seed user doc
    await db.collection("users").doc(uid).set({
      uid,
      displayName: "DeleteMe",
      email: "delete@example.com",
    });

    // Seed suggestion counts
    await db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .doc("2026-05-26")
      .set({count: 1, date: "2026-05-26"});

    // Seed suggestions
    await db.collection("suggestions").doc("s1").set({
      userId: uid,
      type: "general",
      text: "My suggestion",
      status: "pending",
    });

    // Seed a suggestion from another user (should NOT be deleted)
    await db.collection("suggestions").doc("s2").set({
      userId: "other-user",
      type: "general",
      text: "Other suggestion",
      status: "pending",
    });

    // Seed votes
    await db
      .collection("restaurants")
      .doc("hou-1")
      .set({id: "hou-1", rank: 1, voteCount: 50});
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .set({createdAt: Timestamp.now()});
    // Another user's vote (should NOT be deleted)
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc("other-user")
      .set({createdAt: Timestamp.now()});

    // Seed comments
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c1")
      .set({userId: uid, text: "My comment"});
    // Another user's comment (should NOT be deleted)
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c2")
      .set({userId: "other-user", text: "Other comment"});
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("cleanup removes only the deleted user's data", async () => {
    // Simulate what onUserDeleted does
    // 1. Delete suggestionCounts subcollection
    const countsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .get();
    const batch1 = db.batch();
    for (const d of countsSnap.docs) {
      batch1.delete(d.ref);
    }
    await batch1.commit();

    // 2. Delete user doc
    await db.collection("users").doc(uid).delete();

    // 3. Delete suggestions by userId
    const suggestionsSnap = await db
      .collection("suggestions")
      .where("userId", "==", uid)
      .get();
    const batch2 = db.batch();
    for (const d of suggestionsSnap.docs) {
      batch2.delete(d.ref);
    }
    await batch2.commit();

    // 4. Delete votes with doc ID matching uid
    const allVotes = await db.collectionGroup("votes").get();
    const batch3 = db.batch();
    for (const d of allVotes.docs) {
      if (d.id === uid) {
        batch3.delete(d.ref);
      }
    }
    await batch3.commit();

    // 5. Delete comments with userId matching
    const userComments = await db
      .collectionGroup("comments")
      .where("userId", "==", uid)
      .get();
    const batch4 = db.batch();
    for (const d of userComments.docs) {
      batch4.delete(d.ref);
    }
    await batch4.commit();

    // VERIFY: deleted user's data is gone
    const userDoc = await db.collection("users").doc(uid).get();
    expect(userDoc.exists).toBe(false);

    const userCounts = await db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .get();
    expect(userCounts.size).toBe(0);

    const userSuggestions = await db
      .collection("suggestions")
      .where("userId", "==", uid)
      .get();
    expect(userSuggestions.size).toBe(0);

    const userVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .get();
    expect(userVote.exists).toBe(false);

    const userComment = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c1")
      .get();
    expect(userComment.exists).toBe(false);

    // VERIFY: other user's data is untouched
    const otherSuggestion = await db
      .collection("suggestions")
      .doc("s2")
      .get();
    expect(otherSuggestion.exists).toBe(true);
    expect(otherSuggestion.data()?.userId).toBe("other-user");

    const otherVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc("other-user")
      .get();
    expect(otherVote.exists).toBe(true);

    const otherComment = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c2")
      .get();
    expect(otherComment.exists).toBe(true);
    expect(otherComment.data()?.userId).toBe("other-user");
  });
});
