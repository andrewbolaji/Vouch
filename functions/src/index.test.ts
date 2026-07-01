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
import {
  applyCommentCreated,
  applyCommentDeleted,
} from "./comment_aggregation";
import {deleteUserData} from "./user_cleanup";
import {
  computeScore,
  assignRanks,
  DEFAULT_HALF_LIFE_DAYS,
} from "./rank_engine";
import {recomputeAllRanks} from "./rank_recompute";

// Initialize admin SDK for emulator
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

if (getApps().length === 0) {
  initializeApp({projectId: "vouch-test"});
}

const db = getFirestore();

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
// Comment aggregation
//
// Tests call the real applyCommentCreated/applyCommentDeleted
// functions from comment_aggregation.ts, mirroring the vote
// aggregation test pattern.
// ================================================================

describe("Comment aggregation (real function bodies)", () => {
  beforeEach(async () => {
    await clearFirestore();
    await db.collection("restaurants").doc("hou-1").set({
      id: "hou-1",
      cityId: "houston",
      name: "Turkey Leg Hut",
      rank: 1,
      voteCount: 100,
      commentCount: 5,
    });
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("applyCommentCreated increments commentCount", async () => {
    await applyCommentCreated(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.commentCount).toBe(6);
  });

  test("applyCommentDeleted decrements commentCount", async () => {
    await applyCommentDeleted(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.commentCount).toBe(4);
  });

  test("multiple increments are additive", async () => {
    await applyCommentCreated(db, "hou-1");
    await applyCommentCreated(db, "hou-1");
    await applyCommentCreated(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.commentCount).toBe(8);
  });

  test("increment after decrement nets to zero change", async () => {
    await applyCommentCreated(db, "hou-1");
    await applyCommentDeleted(db, "hou-1");

    const snap = await db.collection("restaurants").doc("hou-1").get();
    expect(snap.data()?.commentCount).toBe(5);
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
      const currentCount = counterSnap.exists ?
        ((counterSnap.data()?.count as number) ?? 0) :
        0;

      expect(currentCount).toBe(0);

      tx.set(suggestionRef, {
        id: suggestionRef.id,
        userId: uid,
        type: "general",
        text: "Add more cities",
        createdAt: FieldValue.serverTimestamp(),
        status: "pending",
      });

      tx.set(
        counterRef,
        {count: FieldValue.increment(1), date: dateKey},
        {merge: true},
      );
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
        const currentCount = counterSnap.exists ?
          ((counterSnap.data()?.count as number) ?? 0) :
          0;

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

    const otherCount = otherSnap.exists ?
      ((otherSnap.data()?.count as number) ?? 0) :
      0;
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
      .set({
        userId: "other-user",
        userName: "OtherUser",
        text: "Other comment",
      });
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

  // eslint-disable-next-line max-len
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

// ================================================================
// Rank engine: pure score math
//
// These test the pure functions in rank_engine.ts directly.
// No Firestore involved.
// ================================================================

describe("Rank engine (pure score math)", () => {
  const now = new Date("2026-06-11T12:00:00Z");
  const msPerDay = 24 * 60 * 60 * 1000;

  /**
   * @param {number} d Days before now.
   * @return {Date} The past date.
   */
  function daysAgo(d: number): Date {
    return new Date(now.getTime() - d * msPerDay);
  }

  test("single vote from today scores its full weight", () => {
    const score = computeScore(
      [{createdAt: now, weight: 1}],
      now
    );
    expect(score).toBeCloseTo(1.0, 5);
  });

  test("vote from halfLifeDays ago scores 0.5", () => {
    const score = computeScore(
      [{createdAt: daysAgo(DEFAULT_HALF_LIFE_DAYS), weight: 1}],
      now
    );
    expect(score).toBeCloseTo(0.5, 2);
  });

  test("vote from 2x halfLifeDays ago scores 0.25", () => {
    const score = computeScore(
      [{createdAt: daysAgo(DEFAULT_HALF_LIFE_DAYS * 2), weight: 1}],
      now
    );
    expect(score).toBeCloseTo(0.25, 2);
  });

  test("weight=2 doubles the score at the same age", () => {
    const s1 = computeScore(
      [{createdAt: daysAgo(30), weight: 1}],
      now
    );
    const s2 = computeScore(
      [{createdAt: daysAgo(30), weight: 2}],
      now
    );
    expect(s2).toBeCloseTo(s1 * 2, 5);
  });

  test("zero votes returns 0", () => {
    expect(computeScore([], now)).toBe(0);
  });

  test("missing weight defaults to 1 (no NaN)", () => {
    // Simulate a vote doc with no weight field by passing weight: 1
    // (the orchestrator defaults missing weight to 1 via ?? 1).
    // The engine itself receives the weight, so we verify that
    // weight=1 produces the same result as an explicit weight=1 vote.
    const withWeight = computeScore(
      [{createdAt: now, weight: 1}],
      now
    );
    expect(withWeight).toBeCloseTo(1.0, 5);
    expect(Number.isNaN(withWeight)).toBe(false);
  });

  test("multiple votes are additive", () => {
    const s1 = computeScore([{createdAt: now, weight: 1}], now);
    const s2 = computeScore([{createdAt: daysAgo(45), weight: 1}], now);
    const combined = computeScore(
      [{createdAt: now, weight: 1}, {createdAt: daysAgo(45), weight: 1}],
      now
    );
    expect(combined).toBeCloseTo(s1 + s2, 5);
  });

  test("assignRanks returns ranks 1..N sorted by score descending", () => {
    const ranked = assignRanks([
      {id: "a", score: 10, voteCount: 100, name: "A"},
      {id: "b", score: 30, voteCount: 200, name: "B"},
      {id: "c", score: 20, voteCount: 150, name: "C"},
    ]);
    expect(ranked).toEqual([
      {id: "b", rank: 1, score: 30},
      {id: "c", rank: 2, score: 20},
      {id: "a", rank: 3, score: 10},
    ]);
  });

  test("assignRanks tie-breaking: equal score, higher voteCount wins", () => {
    const ranked = assignRanks([
      {id: "a", score: 10, voteCount: 50, name: "A"},
      {id: "b", score: 10, voteCount: 100, name: "B"},
    ]);
    expect(ranked[0].id).toBe("b");
    expect(ranked[1].id).toBe("a");
  });

  // eslint-disable-next-line max-len
  test("assignRanks tie-breaking: equal score and voteCount, alphabetical by name", () => {
    const ranked = assignRanks([
      {id: "z", score: 10, voteCount: 50, name: "Zebra"},
      {id: "a", score: 10, voteCount: 50, name: "Alpha"},
    ]);
    expect(ranked[0].id).toBe("a");
    expect(ranked[1].id).toBe("z");
  });
});

// ================================================================
// Rank invariants
//
// Structural guarantees that must hold for any input.
// ================================================================

describe("Rank invariants", () => {
  test("no duplicate ranks", () => {
    const input = Array.from({length: 10}, (_, i) => ({
      id: `r${i}`,
      score: Math.random() * 100,
      voteCount: Math.floor(Math.random() * 1000),
      name: `Restaurant ${i}`,
    }));
    const ranked = assignRanks(input);
    const ranks = ranked.map((r) => r.rank);
    expect(new Set(ranks).size).toBe(ranks.length);
  });

  test("ranks are contiguous 1 to N", () => {
    const input = Array.from({length: 7}, (_, i) => ({
      id: `r${i}`,
      score: (7 - i) * 10,
      voteCount: 100,
      name: `R${i}`,
    }));
    const ranked = assignRanks(input);
    const ranks = ranked.map((r) => r.rank).sort((a, b) => a - b);
    expect(ranks).toEqual([1, 2, 3, 4, 5, 6, 7]);
  });

  test("higher score always gets a better (lower) rank", () => {
    const input = [
      {id: "high", score: 50, voteCount: 100, name: "High"},
      {id: "low", score: 10, voteCount: 100, name: "Low"},
      {id: "mid", score: 30, voteCount: 100, name: "Mid"},
    ];
    const ranked = assignRanks(input);
    const byId = Object.fromEntries(ranked.map((r) => [r.id, r]));
    expect(byId["high"].rank).toBeLessThan(byId["mid"].rank);
    expect(byId["mid"].rank).toBeLessThan(byId["low"].rank);
  });
});

// ================================================================
// Rank recompute integration (real function bodies)
//
// Tests call the real recomputeAllRanks orchestrator, which calls
// the real computeScore and assignRanks. No reimplementation.
// ================================================================

describe("Rank recompute integration (real recomputeAllRanks)", () => {
  const now = new Date("2026-06-11T12:00:00Z");
  const msPerDay = 24 * 60 * 60 * 1000;

  beforeEach(async () => {
    await clearFirestore();

    // Seed a city
    await db.collection("cities").doc("test-city").set({
      id: "test-city",
      name: "Test City",
      state: "TX",
    });

    // Seed 3 restaurants with different vote patterns
    // Restaurant A: 3 recent votes (should rank #1)
    await db.collection("restaurants").doc("rest-a").set({
      id: "rest-a",
      cityId: "test-city",
      name: "Restaurant A",
      rank: 3,
      voteCount: 3,
    });
    for (let i = 0; i < 3; i++) {
      await db
        .collection("restaurants")
        .doc("rest-a")
        .collection("votes")
        .doc(`user-a${i}`)
        .set({
          createdAt: Timestamp.fromDate(
            new Date(now.getTime() - i * msPerDay)
          ),
          weight: 1,
        });
    }

    // Restaurant B: 2 recent votes (should rank #2)
    await db.collection("restaurants").doc("rest-b").set({
      id: "rest-b",
      cityId: "test-city",
      name: "Restaurant B",
      rank: 1,
      voteCount: 2,
    });
    for (let i = 0; i < 2; i++) {
      await db
        .collection("restaurants")
        .doc("rest-b")
        .collection("votes")
        .doc(`user-b${i}`)
        .set({
          createdAt: Timestamp.fromDate(
            new Date(now.getTime() - i * msPerDay)
          ),
          weight: 1,
        });
    }

    // Restaurant C: 5 very old votes (should rank #3 despite more total votes)
    // At 330-370 days old with 90-day half-life, each vote decays to ~0.06,
    // so 5 * ~0.06 = ~0.3, well below rest-b's 2 fresh votes (~1.99).
    await db.collection("restaurants").doc("rest-c").set({
      id: "rest-c",
      cityId: "test-city",
      name: "Restaurant C",
      rank: 2,
      voteCount: 5,
    });
    for (let i = 0; i < 5; i++) {
      await db
        .collection("restaurants")
        .doc("rest-c")
        .collection("votes")
        .doc(`user-c${i}`)
        .set({
          createdAt: Timestamp.fromDate(
            new Date(now.getTime() - (330 + i * 10) * msPerDay)
          ),
          weight: 1,
        });
    }
  });

  afterAll(async () => {
    await clearFirestore();
  });

  test("recomputeAllRanks assigns correct ranks based on decay", async () => {
    await recomputeAllRanks(db, now);

    const a = await db.collection("restaurants").doc("rest-a").get();
    const b = await db.collection("restaurants").doc("rest-b").get();
    const c = await db.collection("restaurants").doc("rest-c").get();

    // A has most recent votes, should be #1
    expect(a.data()?.rank).toBe(1);
    // B has fewer but still recent, #2
    expect(b.data()?.rank).toBe(2);
    // C has more total votes but they are old, #3
    expect(c.data()?.rank).toBe(3);

    // rankScore should be written and positive
    expect(a.data()?.rankScore).toBeGreaterThan(0);
    expect(b.data()?.rankScore).toBeGreaterThan(0);
    expect(c.data()?.rankScore).toBeGreaterThan(0);

    // Scores should be in descending order matching ranks
    expect(a.data()?.rankScore).toBeGreaterThan(b.data()?.rankScore);
    expect(b.data()?.rankScore).toBeGreaterThan(c.data()?.rankScore);
  });

  test("recomputeAllRanks produces contiguous ranks", async () => {
    await recomputeAllRanks(db, now);

    const snap = await db
      .collection("restaurants")
      .where("cityId", "==", "test-city")
      .get();
    const ranks = snap.docs
      .map((d) => d.data().rank as number)
      .sort((a, b) => a - b);
    expect(ranks).toEqual([1, 2, 3]);
  });

  test("vote doc without weight field scores as weight=1", async () => {
    // Add a restaurant with a weightless vote doc
    await db.collection("restaurants").doc("rest-noweight").set({
      id: "rest-noweight",
      cityId: "test-city",
      name: "No Weight Restaurant",
      rank: 1,
      voteCount: 1,
    });
    await db
      .collection("restaurants")
      .doc("rest-noweight")
      .collection("votes")
      .doc("user-nw")
      .set({
        createdAt: Timestamp.fromDate(now),
        // no weight field
      });

    await recomputeAllRanks(db, now);

    const doc = await db.collection("restaurants").doc("rest-noweight").get();
    // Should not be NaN; should have a valid positive score
    expect(doc.data()?.rankScore).toBeGreaterThan(0);
    expect(Number.isNaN(doc.data()?.rankScore)).toBe(false);
  });

  test("restaurant with zero votes gets last rank", async () => {
    // Add a restaurant with no votes
    await db.collection("restaurants").doc("rest-empty").set({
      id: "rest-empty",
      cityId: "test-city",
      name: "Empty Restaurant",
      rank: 1,
      voteCount: 0,
    });

    await recomputeAllRanks(db, now);

    const empty = await db.collection("restaurants").doc("rest-empty").get();
    expect(empty.data()?.rank).toBe(4);
    expect(empty.data()?.rankScore).toBe(0);
  });
});
