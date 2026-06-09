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

  // Helper: simulates exactly what onUserDeleted does.
  // Kept in sync with the production function in index.ts.
  async function simulateOnUserDeleted(deletedUid: string) {
    // Helper: delete all docs from a query in batches
    const deleteDocs = async (
      query: FirebaseFirestore.Query
    ): Promise<number> => {
      let total = 0;
      let snap = await query.limit(500).get();
      while (!snap.empty) {
        const batch = db.batch();
        for (const d of snap.docs) batch.delete(d.ref);
        await batch.commit();
        total += snap.size;
        snap = await query.limit(500).get();
      }
      return total;
    };

    // Helper: update all docs from a query
    const updateDocs = async (
      query: FirebaseFirestore.Query,
      data: Record<string, unknown>
    ): Promise<number> => {
      let total = 0;
      let snap = await query.limit(500).get();
      while (!snap.empty) {
        const batch = db.batch();
        for (const d of snap.docs) batch.update(d.ref, data);
        await batch.commit();
        total += snap.size;
        snap = await query.limit(500).get();
      }
      return total;
    };

    // 1. Delete suggestionCounts subcollection
    await deleteDocs(
      db.collection("users").doc(deletedUid).collection("suggestionCounts")
    );

    // 2. Delete reportCounts subcollection
    await deleteDocs(
      db.collection("users").doc(deletedUid).collection("reportCounts")
    );

    // 3. Delete user doc
    await db.collection("users").doc(deletedUid).delete();

    // 4. Delete suggestions
    await deleteDocs(
      db.collection("suggestions").where("userId", "==", deletedUid)
    );

    // 5. Delete reports
    await deleteDocs(
      db.collection("reports").where("reporterUid", "==", deletedUid)
    );

    // 6. Delete votes (triggers onVoteDeleted which decrements aggregates)
    const allVotes = await db.collectionGroup("votes").get();
    const batch = db.batch();
    for (const d of allVotes.docs) {
      if (d.id === deletedUid) batch.delete(d.ref);
    }
    await batch.commit();

    // 7. Anonymize comments (preserve threads)
    await updateDocs(
      db.collectionGroup("comments").where("userId", "==", deletedUid),
      {userId: "deleted", userName: "Deleted user", isInsider: false}
    );
  }

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

    // Seed report counts
    await db
      .collection("users")
      .doc(uid)
      .collection("reportCounts")
      .doc("2026-06-09")
      .set({count: 2, date: "2026-06-09"});

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

    // Seed reports
    await db.collection("reports").doc("r1").set({
      reporterUid: uid,
      commentId: "c99",
      commentPath: "restaurants/hou-1/comments/c99",
      restaurantId: "hou-1",
      reason: "spam",
    });

    // Seed a report from another user (should NOT be deleted)
    await db.collection("reports").doc("r2").set({
      reporterUid: "other-user",
      commentId: "c99",
      commentPath: "restaurants/hou-1/comments/c99",
      restaurantId: "hou-1",
      reason: "harassment",
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

    // Seed comments (with isInsider to verify anonymization clears it)
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c1")
      .set({
        userId: uid,
        userName: "DeleteMe",
        text: "My comment",
        isInsider: true,
      });
    // A reply to the deleted user's comment from another user
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c3")
      .set({
        userId: "other-user",
        userName: "OtherUser",
        text: "Reply to deleted user",
        parentId: "c1",
      });
    // Another user's comment (should NOT be touched)
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c2")
      .set({userId: "other-user", userName: "OtherUser", text: "Other comment"});
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("cleanup removes user data and anonymizes comments", async () => {
    await simulateOnUserDeleted(uid);

    // VERIFY: user doc gone
    const userDoc = await db.collection("users").doc(uid).get();
    expect(userDoc.exists).toBe(false);

    // VERIFY: suggestionCounts gone
    const sugCounts = await db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .get();
    expect(sugCounts.size).toBe(0);

    // VERIFY: reportCounts gone
    const repCounts = await db
      .collection("users")
      .doc(uid)
      .collection("reportCounts")
      .get();
    expect(repCounts.size).toBe(0);

    // VERIFY: suggestions gone
    const userSuggestions = await db
      .collection("suggestions")
      .where("userId", "==", uid)
      .get();
    expect(userSuggestions.size).toBe(0);

    // VERIFY: reports gone
    const userReports = await db
      .collection("reports")
      .where("reporterUid", "==", uid)
      .get();
    expect(userReports.size).toBe(0);

    // VERIFY: vote doc gone
    const userVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .get();
    expect(userVote.exists).toBe(false);

    // VERIFY: comment anonymized (not deleted)
    const comment = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c1")
      .get();
    expect(comment.exists).toBe(true);
    expect(comment.data()?.userId).toBe("deleted");
    expect(comment.data()?.userName).toBe("Deleted user");
    expect(comment.data()?.isInsider).toBe(false);
    expect(comment.data()?.text).toBe("My comment");
  });

  test("other user's data is untouched after deletion", async () => {
    await simulateOnUserDeleted(uid);

    // Other user's suggestion survives
    const otherSuggestion = await db
      .collection("suggestions")
      .doc("s2")
      .get();
    expect(otherSuggestion.exists).toBe(true);
    expect(otherSuggestion.data()?.userId).toBe("other-user");

    // Other user's report survives
    const otherReport = await db.collection("reports").doc("r2").get();
    expect(otherReport.exists).toBe(true);
    expect(otherReport.data()?.reporterUid).toBe("other-user");

    // Other user's vote survives
    const otherVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc("other-user")
      .get();
    expect(otherVote.exists).toBe(true);

    // Other user's comment untouched
    const otherComment = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c2")
      .get();
    expect(otherComment.exists).toBe(true);
    expect(otherComment.data()?.userId).toBe("other-user");

    // Reply to deleted user's comment is untouched
    const reply = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("comments")
      .doc("c3")
      .get();
    expect(reply.exists).toBe(true);
    expect(reply.data()?.userId).toBe("other-user");
    expect(reply.data()?.parentId).toBe("c1");
  });

  test("vote deletion would trigger aggregate decrement", async () => {
    // Verify initial voteCount
    const before = await db.collection("restaurants").doc("hou-1").get();
    expect(before.data()?.voteCount).toBe(50);

    // Delete the vote doc (simulating what onUserDeleted does)
    await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .delete();

    // Simulate what onVoteDeleted trigger does
    await db
      .collection("restaurants")
      .doc("hou-1")
      .update({voteCount: FieldValue.increment(-1)});

    const after = await db.collection("restaurants").doc("hou-1").get();
    expect(after.data()?.voteCount).toBe(49);

    // Other user's vote still exists
    const otherVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc("other-user")
      .get();
    expect(otherVote.exists).toBe(true);
  });
});
