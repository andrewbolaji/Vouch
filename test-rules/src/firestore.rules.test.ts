import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { resolve } from "path";
import {
  doc,
  getDoc,
  setDoc,
  deleteDoc,
  updateDoc,
  collection,
  addDoc,
  query,
  where,
  getDocs,
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "vouch-rules-test";
const RULES_PATH = resolve(__dirname, "../../firestore.rules");

let testEnv: RulesTestEnvironment;

// Helpers for creating authenticated contexts with custom claims.
// All verified by default (email_verified: true) since votes and
// comments now require verification.
function freeUser(uid: string = "free-user") {
  return testEnv.authenticatedContext(uid, {
    membershipTier: "free",
    email_verified: true,
  });
}

function localsPassUser(uid: string = "locals-user") {
  return testEnv.authenticatedContext(uid, {
    membershipTier: "localsPass",
    email_verified: true,
  });
}

function cityInsiderUser(uid: string = "insider-user") {
  return testEnv.authenticatedContext(uid, {
    membershipTier: "cityInsider",
    email_verified: true,
  });
}

function unverifiedUser(uid: string = "unverified-user") {
  return testEnv.authenticatedContext(uid, {
    membershipTier: "free",
    email_verified: false,
  });
}

function unauthenticated() {
  return testEnv.unauthenticatedContext();
}

beforeAll(async () => {
  setLogLevel("error");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

// Seed helper: writes data as admin (bypasses rules)
async function seedAsAdmin(
  path: string,
  data: Record<string, unknown>
) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const ref = doc(ctx.firestore(), path);
    await setDoc(ref, data);
  });
}

// ================================================================
// CITIES
// ================================================================

describe("cities", () => {
  beforeEach(async () => {
    await seedAsAdmin("cities/houston", {
      id: "houston",
      name: "Houston",
      state: "TX",
    });
  });

  test("authenticated user can read a city", async () => {
    const db = freeUser().firestore();
    await assertSucceeds(getDoc(doc(db, "cities/houston")));
  });

  test("unauthenticated user cannot read a city", async () => {
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "cities/houston")));
  });

  test("authenticated user cannot write a city", async () => {
    const db = freeUser().firestore();
    await assertFails(
      setDoc(doc(db, "cities/new-city"), { name: "Test" })
    );
  });

  test("authenticated user cannot delete a city", async () => {
    const db = freeUser().firestore();
    await assertFails(deleteDoc(doc(db, "cities/houston")));
  });
});

// ================================================================
// RESTAURANTS - rank-based gating
// ================================================================

describe("restaurants", () => {
  beforeEach(async () => {
    // Seed restaurants at various ranks
    for (let rank = 1; rank <= 10; rank++) {
      await seedAsAdmin(`restaurants/hou-${rank}`, {
        id: `hou-${rank}`,
        cityId: "houston",
        name: `Restaurant ${rank}`,
        rank,
      });
    }
  });

  test("free user can read restaurant with rank <= 5", async () => {
    const db = freeUser().firestore();
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-1")));
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-5")));
  });

  test("free user DENIED reading restaurant with rank 6 (single doc by ID)", async () => {
    const db = freeUser().firestore();
    await assertFails(getDoc(doc(db, "restaurants/hou-6")));
  });

  test("free user DENIED reading restaurant with rank 10", async () => {
    const db = freeUser().firestore();
    await assertFails(getDoc(doc(db, "restaurants/hou-10")));
  });

  test("localsPass user can read restaurant with rank 6-10", async () => {
    const db = localsPassUser().firestore();
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-6")));
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-10")));
  });

  test("cityInsider user can read restaurant with rank 6-10", async () => {
    const db = cityInsiderUser().firestore();
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-6")));
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-10")));
  });

  test("unauthenticated user cannot read any restaurant", async () => {
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "restaurants/hou-1")));
  });

  test("no user can write a restaurant", async () => {
    const db = cityInsiderUser().firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/new"), { name: "Hack", rank: 1 })
    );
  });

  test("no user can delete a restaurant", async () => {
    const db = cityInsiderUser().firestore();
    await assertFails(deleteDoc(doc(db, "restaurants/hou-1")));
  });
});

// ================================================================
// INSIDER NOTES subcollection
// ================================================================

describe("insiderNotes", () => {
  beforeEach(async () => {
    await seedAsAdmin("restaurants/hou-1", {
      id: "hou-1",
      cityId: "houston",
      rank: 1,
    });
    await seedAsAdmin("restaurants/hou-1/insiderNotes/notes", {
      whatToOrder: "The loaded turkey leg",
      insiderTip: "Go on a weekday",
    });
  });

  test("cityInsider can read insiderNotes", async () => {
    const db = cityInsiderUser().firestore();
    await assertSucceeds(
      getDoc(doc(db, "restaurants/hou-1/insiderNotes/notes"))
    );
  });

  test("localsPass DENIED reading insiderNotes", async () => {
    const db = localsPassUser().firestore();
    await assertFails(
      getDoc(doc(db, "restaurants/hou-1/insiderNotes/notes"))
    );
  });

  test("free user DENIED reading insiderNotes", async () => {
    const db = freeUser().firestore();
    await assertFails(
      getDoc(doc(db, "restaurants/hou-1/insiderNotes/notes"))
    );
  });

  test("unauthenticated user DENIED reading insiderNotes", async () => {
    const db = unauthenticated().firestore();
    await assertFails(
      getDoc(doc(db, "restaurants/hou-1/insiderNotes/notes"))
    );
  });

  test("cityInsider cannot write insiderNotes", async () => {
    const db = cityInsiderUser().firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/insiderNotes/notes"), {
        whatToOrder: "Hacked",
      })
    );
  });
});

// ================================================================
// VOTES
// ================================================================

describe("votes", () => {
  beforeEach(async () => {
    await seedAsAdmin("restaurants/hou-1", {
      id: "hou-1",
      rank: 1,
      voteCount: 100,
    });
  });

  test("user can create a vote doc with their own UID and weight 1", async () => {
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
    );
  });

  test("user DENIED creating a vote doc with another UID", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/bob"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
    );
  });

  test("user DENIED creating a vote with weight != 1", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 2,
      })
    );
  });

  test("user DENIED creating a vote without weight field", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
      })
    );
  });

  test("unverified email user DENIED creating a vote", async () => {
    const db = unverifiedUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
    );
  });

  test("user can delete their own vote", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      deleteDoc(doc(db, "restaurants/hou-1/votes/alice"))
    );
  });

  test("user DENIED deleting another user's vote", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/bob", {
      createdAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      deleteDoc(doc(db, "restaurants/hou-1/votes/bob"))
    );
  });

  test("user DENIED updating a vote (no updates allowed)", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
      })
    );
  });

  test("authenticated user can read a vote doc (hasVoted check)", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = freeUser("bob").firestore();
    await assertSucceeds(
      getDoc(doc(db, "restaurants/hou-1/votes/alice"))
    );
  });

  test("unauthenticated user DENIED reading a vote", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = unauthenticated().firestore();
    await assertFails(
      getDoc(doc(db, "restaurants/hou-1/votes/alice"))
    );
  });
});

// ================================================================
// COMMENTS
// ================================================================

describe("comments", () => {
  const userUid = "commenter-1";

  beforeEach(async () => {
    await seedAsAdmin("restaurants/hou-1", {
      id: "hou-1",
      rank: 1,
    });
    // Seed the user doc so userName validation can look it up
    await seedAsAdmin(`users/${userUid}`, {
      id: userUid,
      displayName: "TestUser",
      email: "test@example.com",
      membershipTier: "free",
    });
  });

  function validComment(overrides: Record<string, unknown> = {}) {
    return {
      userId: userUid,
      userName: "TestUser",
      text: "Great food!",
      parentId: null,
      isInsider: false,
      createdAt: serverTimestamp(),
      ...overrides,
    };
  }

  test("authenticated user can read comments", async () => {
    await seedAsAdmin("restaurants/hou-1/comments/c1", {
      userId: userUid,
      text: "Hello",
    });
    const db = freeUser("anyone").firestore();
    await assertSucceeds(
      getDoc(doc(db, "restaurants/hou-1/comments/c1"))
    );
  });

  test("valid comment create succeeds", async () => {
    const db = freeUser(userUid).firestore();
    await assertSucceeds(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment()
      )
    );
  });

  test("DENIED: comment with mismatched userId (impersonation)", async () => {
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ userId: "someone-else" })
      )
    );
  });

  test("DENIED: comment with spoofed userName (not matching user doc)", async () => {
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ userName: "FakeNameHacker" })
      )
    );
  });

  test("DENIED: comment with spoofed isInsider=true (free user)", async () => {
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ isInsider: true })
      )
    );
  });

  test("cityInsider can create comment with isInsider=true", async () => {
    const insiderUid = "insider-commenter";
    await seedAsAdmin(`users/${insiderUid}`, {
      id: insiderUid,
      displayName: "InsiderUser",
      email: "insider@example.com",
      membershipTier: "cityInsider",
    });
    const db = cityInsiderUser(insiderUid).firestore();
    await assertSucceeds(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        {
          userId: insiderUid,
          userName: "InsiderUser",
          text: "Insider comment",
          parentId: null,
          isInsider: true,
          createdAt: serverTimestamp(),
        }
      )
    );
  });

  test("DENIED: empty text", async () => {
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ text: "" })
      )
    );
  });

  test("DENIED: text over 500 chars", async () => {
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ text: "x".repeat(501) })
      )
    );
  });

  test("text at exactly 500 chars succeeds", async () => {
    const db = freeUser(userUid).firestore();
    await assertSucceeds(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment({ text: "x".repeat(500) })
      )
    );
  });

  test("comment author can delete their own comment", async () => {
    await seedAsAdmin("restaurants/hou-1/comments/c1", {
      userId: userUid,
      text: "My comment",
    });
    const db = freeUser(userUid).firestore();
    await assertSucceeds(
      deleteDoc(doc(db, "restaurants/hou-1/comments/c1"))
    );
  });

  test("DENIED: user cannot delete another user's comment", async () => {
    await seedAsAdmin("restaurants/hou-1/comments/c1", {
      userId: "other-user",
      text: "Their comment",
    });
    const db = freeUser(userUid).firestore();
    await assertFails(
      deleteDoc(doc(db, "restaurants/hou-1/comments/c1"))
    );
  });

  test("DENIED: comment update (no updates allowed)", async () => {
    await seedAsAdmin("restaurants/hou-1/comments/c1", {
      userId: userUid,
      text: "Original",
    });
    const db = freeUser(userUid).firestore();
    await assertFails(
      updateDoc(doc(db, "restaurants/hou-1/comments/c1"), {
        text: "Edited",
      })
    );
  });

  test("unauthenticated user DENIED creating comment", async () => {
    const db = unauthenticated().firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment()
      )
    );
  });

  test("unverified email user DENIED creating comment", async () => {
    const unvUid = "unverified-commenter";
    await seedAsAdmin(`users/${unvUid}`, {
      id: unvUid,
      displayName: "Unverified",
      email: "unv@test.com",
      membershipTier: "free",
    });
    const db = testEnv.authenticatedContext(unvUid, {
      membershipTier: "free",
      email_verified: false,
    }).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        {
          userId: unvUid,
          userName: "Unverified",
          text: "Should be blocked",
          parentId: null,
          isInsider: false,
          createdAt: serverTimestamp(),
        }
      )
    );
  });
});

// ================================================================
// USERS
// ================================================================

describe("users", () => {
  test("user can read their own doc", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "users/alice")));
  });

  test("DENIED: user cannot read another user's doc", async () => {
    await seedAsAdmin("users/bob", {
      id: "bob",
      displayName: "Bob",
      email: "bob@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDoc(doc(db, "users/bob")));
  });

  test("user can create their own doc", async () => {
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      setDoc(doc(db, "users/alice"), {
        id: "alice",
        displayName: "Alice",
        email: "alice@test.com",
      })
    );
  });

  test("DENIED: user cannot create another user's doc", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/bob"), {
        id: "bob",
        displayName: "Bob",
        email: "bob@test.com",
      })
    );
  });

  test("user can update their own doc without changing id", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        displayName: "Alice Updated",
      })
    );
  });

  test("DENIED: user cannot change id field on update", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice"), {
        id: "hacked-id",
        displayName: "Alice",
        email: "alice@test.com",
      })
    );
  });

  test("DENIED: user cannot update another user's doc", async () => {
    await seedAsAdmin("users/bob", {
      id: "bob",
      displayName: "Bob",
      email: "bob@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "users/bob"), {
        displayName: "Hacked",
      })
    );
  });

  test("unauthenticated user DENIED reading any user doc", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
    });
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "users/alice")));
  });

  // Block tests: seed the user doc with the EXACT fields the app
  // writes via UserProfile.toJson() (field is "id", not "uid").
  test("addBlock: arrayUnion on blockedUserIds with real app doc shape", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
      membershipTier: "free",
      savedRestaurantIds: [],
      blockedUserIds: [],
      createdAt: new Date(),
      lastActiveAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        blockedUserIds: ["blocked-user-1"],
      })
    );
  });

  // eslint-disable-next-line max-len
  test("updateSaved: arrayUnion on savedRestaurantIds with real app doc shape", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
      membershipTier: "free",
      savedRestaurantIds: [],
      blockedUserIds: [],
      createdAt: new Date(),
      lastActiveAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        savedRestaurantIds: ["hou-1"],
      })
    );
  });

  // eslint-disable-next-line max-len
  test("removeBlock: arrayRemove on blockedUserIds with real app doc shape", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
      membershipTier: "free",
      savedRestaurantIds: [],
      blockedUserIds: ["blocked-user-1"],
      createdAt: new Date(),
      lastActiveAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        blockedUserIds: [],
      })
    );
  });
});

// ================================================================
// SUGGESTION COUNTS subcollection
// ================================================================

describe("suggestionCounts", () => {
  test("user can read their own suggestionCounts", async () => {
    await seedAsAdmin("users/alice/suggestionCounts/2026-05-26", {
      count: 1,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      getDoc(doc(db, "users/alice/suggestionCounts/2026-05-26"))
    );
  });

  test("DENIED: user cannot read another user's suggestionCounts", async () => {
    await seedAsAdmin("users/bob/suggestionCounts/2026-05-26", {
      count: 1,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      getDoc(doc(db, "users/bob/suggestionCounts/2026-05-26"))
    );
  });

  test("DENIED: client cannot write to suggestionCounts", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice/suggestionCounts/2026-05-26"), {
        count: 0,
        date: "2026-05-26",
      })
    );
  });

  test("DENIED: client cannot delete suggestionCounts", async () => {
    await seedAsAdmin("users/alice/suggestionCounts/2026-05-26", {
      count: 1,
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      deleteDoc(doc(db, "users/alice/suggestionCounts/2026-05-26"))
    );
  });
});

// ================================================================
// SUGGESTIONS
// ================================================================

describe("suggestions", () => {
  test("user can read their own suggestion", async () => {
    await seedAsAdmin("suggestions/s1", {
      userId: "alice",
      type: "general",
      text: "Add more cities",
      status: "pending",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "suggestions/s1")));
  });

  test("DENIED: user cannot read another user's suggestion", async () => {
    await seedAsAdmin("suggestions/s1", {
      userId: "bob",
      type: "general",
      text: "Bob's suggestion",
      status: "pending",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDoc(doc(db, "suggestions/s1")));
  });

  test("DENIED: client cannot create a suggestion directly", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      addDoc(collection(db, "suggestions"), {
        userId: "alice",
        type: "general",
        text: "Direct write attempt",
        status: "pending",
      })
    );
  });

  test("DENIED: client cannot update a suggestion", async () => {
    await seedAsAdmin("suggestions/s1", {
      userId: "alice",
      type: "general",
      text: "Original",
      status: "pending",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "suggestions/s1"), {
        status: "accepted",
      })
    );
  });

  test("DENIED: client cannot delete a suggestion", async () => {
    await seedAsAdmin("suggestions/s1", {
      userId: "alice",
      type: "general",
      text: "Test",
      status: "pending",
    });
    const db = freeUser("alice").firestore();
    await assertFails(deleteDoc(doc(db, "suggestions/s1")));
  });

  test("unauthenticated user DENIED reading suggestions", async () => {
    await seedAsAdmin("suggestions/s1", {
      userId: "alice",
      type: "general",
      text: "Test",
    });
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "suggestions/s1")));
  });
});

// ================================================================
// REPORTS
// ================================================================

describe("reports", () => {
  const validReport = {
    reporterUid: "alice",
    commentId: "c1",
    commentPath: "restaurants/hou-1/comments/c1",
    restaurantId: "hou-1",
    cityId: "houston",
    reason: "spam",
    createdAt: serverTimestamp(),
  };

  test("authenticated user can create own report", async () => {
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      addDoc(collection(db, "reports"), validReport)
    );
  });

  test("unverified email user CAN create own report (safety feature)", async () => {
    const unvUid = "unv-reporter";
    const db = testEnv.authenticatedContext(unvUid, {
      membershipTier: "free",
      email_verified: false,
    }).firestore();
    await assertSucceeds(
      addDoc(collection(db, "reports"), {
        ...validReport,
        reporterUid: unvUid,
      })
    );
  });

  test("DENIED: create report as another user", async () => {
    const db = freeUser("bob").firestore();
    await assertFails(
      addDoc(collection(db, "reports"), validReport)
    );
  });

  test("DENIED: create report with invalid reason", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      addDoc(collection(db, "reports"), {
        ...validReport,
        reason: "made-up-reason",
      })
    );
  });

  test("user can read own report", async () => {
    await seedAsAdmin("reports/r1", {
      reporterUid: "alice",
      commentId: "c1",
      commentPath: "restaurants/hou-1/comments/c1",
      restaurantId: "hou-1",
      reason: "spam",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "reports/r1")));
  });

  test("DENIED: read another user's report", async () => {
    await seedAsAdmin("reports/r1", {
      reporterUid: "alice",
      commentId: "c1",
      commentPath: "restaurants/hou-1/comments/c1",
      restaurantId: "hou-1",
      reason: "spam",
    });
    const db = freeUser("bob").firestore();
    await assertFails(getDoc(doc(db, "reports/r1")));
  });

  test("DENIED: update a report", async () => {
    await seedAsAdmin("reports/r1", {
      reporterUid: "alice",
      commentId: "c1",
      commentPath: "restaurants/hou-1/comments/c1",
      restaurantId: "hou-1",
      reason: "spam",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "reports/r1"), { reason: "harassment" })
    );
  });

  test("DENIED: delete a report", async () => {
    await seedAsAdmin("reports/r1", {
      reporterUid: "alice",
      commentId: "c1",
      commentPath: "restaurants/hou-1/comments/c1",
      restaurantId: "hou-1",
      reason: "spam",
    });
    const db = freeUser("alice").firestore();
    await assertFails(deleteDoc(doc(db, "reports/r1")));
  });

  test("DENIED: unauthenticated user cannot create report", async () => {
    const db = unauthenticated().firestore();
    await assertFails(
      addDoc(collection(db, "reports"), validReport)
    );
  });
});
