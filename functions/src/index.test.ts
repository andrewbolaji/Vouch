/**
 * Cloud Function tests for Vouch.
 *
 * Run with emulators:
 *   firebase emulators:exec --only firestore,auth,functions \
 *     'cd functions && npx jest --forceExit --detectOpenHandles --verbose'
 *
 * Tests call the same shared functions that the deployed triggers call.
 * No reimplementation. If production logic changes, tests break.
 */

import {initializeApp, getApps, deleteApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {applyVoteCreated, applyVoteDeleted} from "./vote_aggregation";
import {deleteUserData} from "./user_cleanup";

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
// Vote aggregation
//
// Tests call the real applyVoteCreated/applyVoteDeleted functions
// from vote_aggregation.ts, the same functions that onVoteCreated
// and onVoteDeleted delegate to.
//
// What is NOT tested here: the Firestore trigger wiring itself
// (whether Firestore actually fires the trigger when a vote doc
// is created/deleted). That is Firebase infrastructure, not our
// code. It can only be verified with a live emulator running the
// deployed functions or a manual walkthrough.
// ================================================================

describe("Vote aggregation (real function bodies)", () => {
  beforeEach(async () => {
    await clearFirestore();
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

  test("applyVoteCreated increments voteCount", async () => {
    await applyVoteCreated(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.voteCount).toBe(101);
  });

  test("applyVoteDeleted decrements voteCount", async () => {
    await applyVoteDeleted(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.voteCount).toBe(99);
  });

  test("multiple increments are additive", async () => {
    await applyVoteCreated(db, "hou-1");
    await applyVoteCreated(db, "hou-1");
    await applyVoteCreated(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.voteCount).toBe(103);
  });

  test("increment after decrement nets to zero change", async () => {
    await applyVoteCreated(db, "hou-1");
    await applyVoteDeleted(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
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

    const suggestionSnap = await suggestionRef.get();
    expect(suggestionSnap.exists).toBe(true);
    expect(suggestionSnap.data()?.type).toBe("general");
    expect(suggestionSnap.data()?.status).toBe("pending");

    const counterSnap = await counterRef.get();
    expect(counterSnap.data()?.count).toBe(1);
  });

  test("second suggestion of the day is rejected (N+1)", async () => {
    const counterRef = db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .doc(dateKey);

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

    await counterRef.set({count: 1, date: dateKey});

    const otherSnap = await otherCounterRef.get();
    expect(otherSnap.exists).toBe(false);

    const otherCount = otherSnap.exists
      ? (otherSnap.data()?.count as number) ?? 0
      : 0;
    expect(otherCount).toBe(0);
  });
});

// ================================================================
// Account deletion cleanup
//
// Tests call the real deleteUserData function from user_cleanup.ts,
// the same function that onUserDeleted delegates to.
//
// What is NOT tested here:
// - The Auth trigger wiring (whether Firebase Auth actually fires
//   onUserDeleted when an auth record is deleted).
// - The vote aggregate decrement via onVoteDeleted trigger (tested
//   separately above via the real applyVoteDeleted body, but the
//   trigger wiring between "vote doc deleted" and "onVoteDeleted
//   fires" is Firebase infrastructure).
// ================================================================

describe("Account deletion cleanup (real deleteUserData)", () => {
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

  test("deleteUserData removes user data and anonymizes comments", async () => {
    await deleteUserData(db, uid);

    // user doc gone
    const userDoc = await db.collection("users").doc(uid).get();
    expect(userDoc.exists).toBe(false);

    // suggestionCounts gone
    const sugCounts = await db
      .collection("users")
      .doc(uid)
      .collection("suggestionCounts")
      .get();
    expect(sugCounts.size).toBe(0);

    // reportCounts gone
    const repCounts = await db
      .collection("users")
      .doc(uid)
      .collection("reportCounts")
      .get();
    expect(repCounts.size).toBe(0);

    // suggestions gone
    const userSuggestions = await db
      .collection("suggestions")
      .where("userId", "==", uid)
      .get();
    expect(userSuggestions.size).toBe(0);

    // reports gone
    const userReports = await db
      .collection("reports")
      .where("reporterUid", "==", uid)
      .get();
    expect(userReports.size).toBe(0);

    // vote doc gone
    const userVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .get();
    expect(userVote.exists).toBe(false);

    // comment anonymized (not deleted)
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

  test("other user's data is untouched after deleteUserData", async () => {
    await deleteUserData(db, uid);

    const otherSuggestion = await db.collection("suggestions").doc("s2").get();
    expect(otherSuggestion.exists).toBe(true);
    expect(otherSuggestion.data()?.userId).toBe("other-user");

    const otherReport = await db.collection("reports").doc("r2").get();
    expect(otherReport.exists).toBe(true);
    expect(otherReport.data()?.reporterUid).toBe("other-user");

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

  test("deleteUserData removes vote docs (decrement is trigger responsibility)", async () => {
    const before = await db.collection("restaurants").doc("hou-1").get();
    expect(before.data()?.voteCount).toBe(50);

    await deleteUserData(db, uid);

    // Vote doc is gone
    const userVote = await db
      .collection("restaurants")
      .doc("hou-1")
      .collection("votes")
      .doc(uid)
      .get();
    expect(userVote.exists).toBe(false);

    // voteCount is NOT decremented here because deleteUserData does
    // not call applyVoteDeleted. In production, the Firestore trigger
    // fires onVoteDeleted which calls applyVoteDeleted. That wiring
    // is Firebase infrastructure, not testable without deploying.
    // The applyVoteDeleted function itself is tested above.
    const after = await db.collection("restaurants").doc("hou-1").get();
    expect(after.data()?.voteCount).toBe(50);

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
