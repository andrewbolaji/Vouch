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
  Timestamp,
  increment,
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

  test("unauthenticated user CAN read a city", async () => {
    const db = unauthenticated().firestore();
    await assertSucceeds(getDoc(doc(db, "cities/houston")));
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

  test("unauthenticated user CAN read a rank-1 restaurant", async () => {
    const db = unauthenticated().firestore();
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-1")));
  });

  test("unauthenticated user CAN read a rank-5 restaurant", async () => {
    const db = unauthenticated().firestore();
    await assertSucceeds(getDoc(doc(db, "restaurants/hou-5")));
  });

  test("unauthenticated user DENIED reading a rank-6 restaurant", async () => {
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "restaurants/hou-6")));
  });

  test("unauthenticated user DENIED reading a rank-10 restaurant", async () => {
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "restaurants/hou-10")));
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

  test("no user can write commentCount directly", async () => {
    const db = cityInsiderUser().firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1"), { commentCount: 999 }, { merge: true })
    );
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

  test("user can get their own vote doc (hasVoted check)", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      getDoc(doc(db, "restaurants/hou-1/votes/alice"))
    );
  });

  // Was previously allowed, justified by a code comment saying
  // "Reads allowed so clients can check hasVoted via a single doc
  // get." That justification did not match the app: AppState's real
  // hasVoted read local SharedPreferences-backed state only, never
  // this path, so nothing in the app actually needed one user to
  // read another user's vote. Fixed 2026-08-13.
  test("DENIED: authenticated user cannot get another user's vote doc", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    const db = freeUser("bob").firestore();
    await assertFails(
      getDoc(doc(db, "restaurants/hou-1/votes/alice"))
    );
  });

  test("DENIED: authenticated user cannot list the votes collection", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
    });
    await seedAsAdmin("restaurants/hou-1/votes/bob", {
      createdAt: new Date(),
    });
    const db = freeUser("bob").firestore();
    await assertFails(
      getDocs(collection(db, "restaurants/hou-1/votes"))
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
// VOTE INTEGRITY: one vote per user per restaurant, at server time,
// never reassigned, spoofed, backdated, or mutated.
//
// createdAt == request.time was missing from the votes create rule
// until this suite exposed it: a client could write any createdAt it
// wanted, and rank_engine.computeScore trusts that field for decay.
// Every case below must be DENIED.
// ================================================================

describe("vote integrity: no double votes, spoofing, backdating, or tampering", () => {
  beforeEach(async () => {
    await seedAsAdmin("restaurants/hou-1", {
      id: "hou-1",
      rank: 1,
      voteCount: 100,
    });
  });

  test("DENIED: voting twice as the same user on the same restaurant", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
      weight: 1,
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
    );
  });

  test("DENIED: writing any weight other than 1", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 5,
      })
    );
  });

  test("DENIED: writing a vote with someone else's userId (their UID)", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/bob"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
    );
  });

  test("DENIED: a past client timestamp instead of request.time", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: Timestamp.fromDate(new Date("2020-01-01T00:00:00Z")),
        weight: 1,
      })
    );
  });

  test("DENIED: a future client timestamp instead of request.time", async () => {
    const oneYearFromNow = new Date(
      Date.now() + 365 * 24 * 60 * 60 * 1000
    );
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: Timestamp.fromDate(oneYearFromNow),
        weight: 1,
      })
    );
  });

  test("DENIED: updating or mutating an existing vote document", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/alice", {
      createdAt: new Date(),
      weight: 1,
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        weight: 2,
      })
    );
  });

  test("DENIED: deleting another user's vote", async () => {
    await seedAsAdmin("restaurants/hou-1/votes/bob", {
      createdAt: new Date(),
      weight: 1,
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      deleteDoc(doc(db, "restaurants/hou-1/votes/bob"))
    );
  });

  test("DENIED: voting with an unverified email", async () => {
    const db = unverifiedUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "restaurants/hou-1/votes/alice"), {
        createdAt: serverTimestamp(),
        weight: 1,
      })
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

  test("DENIED: direct client create, even with a fully valid payload", async () => {
    // submitComment is the only path that can create a comment now:
    // it runs the content filter server-side and writes via the
    // Admin SDK, which bypasses this rule entirely. A payload that
    // would have passed every field-level check under the old rule
    // (right userId, right userName, right isInsider, valid text
    // length, server timestamp) must still be denied, because the
    // rule denies create outright rather than validating fields.
    const db = freeUser(userUid).firestore();
    await assertFails(
      addDoc(
        collection(db, "restaurants/hou-1/comments"),
        validComment()
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

  // votedRestaurantIds is maintained by the onVoteCreated /
  // onVoteDeleted triggers via the Admin SDK. A client forging it
  // could only mislead its own UI, but it is the one field the
  // client is meant to treat as server truth, so it must not be
  // client-writable. Seeded without the field on purpose: the rule
  // uses the .get(..., []) form specifically so it still evaluates
  // against documents written before this field existed.
  test("DENIED: user cannot add a votedRestaurantIds entry", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "users/alice"), {
        votedRestaurantIds: ["hou-1"],
      })
    );
  });

  test("DENIED: user cannot alter an existing votedRestaurantIds", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
      votedRestaurantIds: ["hou-1"],
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "users/alice"), {
        votedRestaurantIds: ["hou-1", "hou-2"],
      })
    );
  });

  // A vote can be cast before the profile document exists: the vote
  // create rule checks isOwner, isEmailVerified, weight and
  // createdAt, and never looks at users/{uid}. When that happens the
  // onVoteCreated trigger's set(..., merge) creates the profile with
  // votedRestaurantIds and nothing else. If the update rule compares
  // request.resource.data.id to resource.data.id on such a document,
  // the missing field denies every future update the owner makes,
  // permanently: they cannot add the id, because adding it is itself
  // an update that has to pass the same clause, and ensureUserDoc
  // takes its doc-exists branch and is denied too.
  test("a profile with no id field does not lock its owner out", async () => {
    await seedAsAdmin("users/alice", {
      votedRestaurantIds: ["hou-1"],
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        displayName: "Alice",
      })
    );
  });

  // The id immutability the clause exists for must survive the
  // tolerant form: an owner still cannot drop or change it.
  test("DENIED: dropping an existing id field on update", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice"), {
        displayName: "Alice Updated",
      })
    );
  });

  // Whole-document write shapes against a profile that has votes.
  //
  // These pin behaviour the rule already had rather than behaviour
  // it gained: the rule is right in every case below. They exist
  // because the previous coverage never exercised a full document
  // carrying this field at all (the unrelated-update test uses a
  // single named field, and the id tests use documents where both
  // sides default to []), so nothing recorded that whole-document
  // overwrites are simply not a usable shape on users/{uid}.
  test("DENIED: a full document write carrying a stale empty list",
    async () => {
      await seedAsAdmin("users/alice", {
        id: "alice",
        displayName: "Alice",
        votedRestaurantIds: ["hou-1"],
      });
      const db = freeUser("alice").firestore();
      await assertFails(
        setDoc(doc(db, "users/alice"), {
          id: "alice",
          displayName: "Alice Updated",
          votedRestaurantIds: [],
        })
      );
    });

  // The one that matters for the model fix: dropping the field from
  // the payload does not rescue a whole-document write, because a
  // non-merge set deletes the server's list, which is itself a
  // change the rule denies. Excluding the field from serialization
  // stops the model forging a value; it does not make this shape
  // legal.
  test("DENIED: a full document write that omits the field entirely",
    async () => {
      await seedAsAdmin("users/alice", {
        id: "alice",
        displayName: "Alice",
        votedRestaurantIds: ["hou-1"],
      });
      const db = freeUser("alice").firestore();
      await assertFails(
        setDoc(doc(db, "users/alice"), {
          id: "alice",
          displayName: "Alice Updated",
        })
      );
    });

  // The two shapes the client actually uses, both safe on a voted
  // profile: a merge set leaves the untouched field in place, and a
  // named-field update never mentions it.
  test("a merge write omitting the field succeeds", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      votedRestaurantIds: ["hou-1"],
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "users/alice"),
        {displayName: "Alice Updated"},
        {merge: true}
      )
    );
  });

  test("a named-field update on a voted profile succeeds", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      votedRestaurantIds: ["hou-1"],
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {displayName: "Alice Updated"})
    );
  });

  // The lock above must not turn into a blanket write freeze on the
  // rest of the document.
  test("unrelated update still succeeds alongside the vote lock", async () => {
    await seedAsAdmin("users/alice", {
      id: "alice",
      displayName: "Alice",
      email: "alice@test.com",
      votedRestaurantIds: ["hou-1"],
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users/alice"), {
        displayName: "Alice Updated",
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

// ================================================================
// REPORT COUNTS INTEGRITY: a client can move its own daily counter
// forward by exactly 1 per report, and cannot reset or bank it.
//
// count and date had no validation at all until this suite found
// it: a user could set count to 0 to reset their own report rate
// limit, or to a large negative number to bank unlimited future
// reports. Every adversarial case below must be DENIED; the
// legitimate increment path (the one report_repository.dart
// actually uses) must still succeed.
// ================================================================

describe("reportCounts integrity: no resetting or banking your own rate limit", () => {
  test("user can create today's counter at count 1", async () => {
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "users/alice/reportCounts/2026-05-26"),
        {count: increment(1), date: "2026-05-26"},
        {merge: true}
      )
    );
  });

  test("user can increment an existing counter by exactly 1", async () => {
    await seedAsAdmin("users/alice/reportCounts/2026-05-26", {
      count: 1,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "users/alice/reportCounts/2026-05-26"),
        {count: increment(1), date: "2026-05-26"},
        {merge: true}
      )
    );
  });

  test("DENIED: resetting your own counter to 0", async () => {
    await seedAsAdmin("users/alice/reportCounts/2026-05-26", {
      count: 5,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice/reportCounts/2026-05-26"), {
        count: 0,
        date: "2026-05-26",
      })
    );
  });

  test("DENIED: banking your own counter with a large negative value", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice/reportCounts/2026-05-26"), {
        count: -999999,
        date: "2026-05-26",
      })
    );
  });

  test("DENIED: jumping the counter by more than 1", async () => {
    await seedAsAdmin("users/alice/reportCounts/2026-05-26", {
      count: 1,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice/reportCounts/2026-05-26"), {
        count: 10,
        date: "2026-05-26",
      })
    );
  });

  test("DENIED: a date that does not match the document's dateKey", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/alice/reportCounts/2026-05-26"), {
        count: 1,
        date: "2020-01-01",
      })
    );
  });

  test("DENIED: writing another user's reportCounts", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "users/bob/reportCounts/2026-05-26"), {
        count: 1,
        date: "2026-05-26",
      })
    );
  });

  test("DENIED: deleting your own reportCounts document", async () => {
    await seedAsAdmin("users/alice/reportCounts/2026-05-26", {
      count: 1,
      date: "2026-05-26",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      deleteDoc(doc(db, "users/alice/reportCounts/2026-05-26"))
    );
  });
});

// ================================================================
// WAITLIST (admin-only, all client access denied)
// ================================================================

describe("waitlist", () => {
  test("DENIED: unauthenticated user cannot read waitlist", async () => {
    await seedAsAdmin("waitlist/test-at-example-com", {
      email: "test@example.com",
      source: "landing",
    });
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "waitlist/test-at-example-com")));
  });

  test("DENIED: unauthenticated user cannot write waitlist", async () => {
    const db = unauthenticated().firestore();
    await assertFails(
      setDoc(doc(db, "waitlist/bot-signup"), {
        email: "bot@example.com",
        source: "landing",
      })
    );
  });

  test("DENIED: authenticated user cannot read waitlist", async () => {
    await seedAsAdmin("waitlist/test-at-example-com", {
      email: "test@example.com",
      source: "landing",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDoc(doc(db, "waitlist/test-at-example-com")));
  });

  test("DENIED: authenticated user cannot write waitlist", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "waitlist/alice-signup"), {
        email: "alice@example.com",
        source: "landing",
      })
    );
  });
});

// ================================================================
// WAITLIST IP COUNTS (finding 15's rate limit, admin-only)
//
// The write denial is the one that matters: the document holds the
// count, so a client that could write it could reset its own limit
// and the rate limit would be decorative. The read denial matters
// too, for a different reason: the documents are keyed by IP address
// and carry signup volume.
// ================================================================

describe("waitlistIpCounts", () => {
  test("DENIED: unauthenticated user cannot read the counters", async () => {
    await seedAsAdmin("waitlistIpCounts/2026-08-16_203.0.113.7", {
      ip: "203.0.113.7",
      dateKey: "2026-08-16",
      count: 3,
    });
    const db = unauthenticated().firestore();
    await assertFails(
      getDoc(doc(db, "waitlistIpCounts/2026-08-16_203.0.113.7"))
    );
  });

  test("DENIED: unauthenticated user cannot reset a counter", async () => {
    await seedAsAdmin("waitlistIpCounts/2026-08-16_203.0.113.7", {
      ip: "203.0.113.7",
      dateKey: "2026-08-16",
      count: 20,
    });
    const db = unauthenticated().firestore();
    await assertFails(
      setDoc(doc(db, "waitlistIpCounts/2026-08-16_203.0.113.7"), {
        ip: "203.0.113.7",
        dateKey: "2026-08-16",
        count: 0,
      })
    );
  });

  test("DENIED: authenticated user cannot read the counters", async () => {
    await seedAsAdmin("waitlistIpCounts/2026-08-16_203.0.113.7", {
      ip: "203.0.113.7",
      dateKey: "2026-08-16",
      count: 3,
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      getDoc(doc(db, "waitlistIpCounts/2026-08-16_203.0.113.7"))
    );
  });

  test("DENIED: authenticated user cannot reset a counter", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "waitlistIpCounts/2026-08-16_203.0.113.7"), {
        ip: "203.0.113.7",
        dateKey: "2026-08-16",
        count: 0,
      })
    );
  });
});

// ================================================================
// WEBHOOK EVENTS AND MEMBERSHIP STATE (finding 5, admin-only)
//
// The write denials are the load bearing ones. membershipState holds
// the watermark that decides whether an incoming subscription event
// is too old to apply; a user who could rewind their own watermark
// could replay an old EXPIRATION onto themselves, and a user who
// could mark an event done could make a downgrade disappear.
// ================================================================

describe("webhookEvents", () => {
  test("DENIED: a user cannot read the subscription event log",
    async () => {
      await seedAsAdmin("webhookEvents/evt-1", {
        eventId: "evt-1",
        uid: "alice",
        type: "INITIAL_PURCHASE",
        status: "done",
      });
      const db = freeUser("alice").firestore();
      await assertFails(getDoc(doc(db, "webhookEvents/evt-1")));
    });

  test("DENIED: a user cannot mark an event done", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "webhookEvents/evt-2"), {
        eventId: "evt-2",
        uid: "alice",
        status: "done",
      })
    );
  });

  test("DENIED: unauthenticated access is refused both ways", async () => {
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "webhookEvents/evt-1")));
    await assertFails(setDoc(doc(db, "webhookEvents/evt-3"), {status: "done"}));
  });
});

describe("membershipState", () => {
  test("DENIED: a user cannot read their own watermark", async () => {
    await seedAsAdmin("membershipState/alice", {
      uid: "alice",
      lastEventTimestampMs: 5000,
      tier: "localsPass",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDoc(doc(db, "membershipState/alice")));
  });

  test("DENIED: a user cannot rewind their own watermark", async () => {
    // The attack the denial exists for: rewind the watermark, and an
    // old EXPIRATION stops looking stale and applies.
    await seedAsAdmin("membershipState/alice", {
      uid: "alice",
      lastEventTimestampMs: 5000,
      tier: "localsPass",
    });
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "membershipState/alice"), {
        uid: "alice",
        lastEventTimestampMs: 0,
      })
    );
  });

  test("DENIED: a user cannot write somebody else's watermark",
    async () => {
      const db = freeUser("mallory").firestore();
      await assertFails(
        setDoc(doc(db, "membershipState/alice"), {
          uid: "alice",
          lastEventTimestampMs: 0,
        })
      );
    });
});

describe("voteEvents", () => {
  test("DENIED: unauthenticated user cannot read voteEvents", async () => {
    await seedAsAdmin("voteEvents/evt-1", {
      eventId: "evt-1",
      type: "create",
      userId: "alice",
      restaurantId: "hou-1",
      cityId: "houston",
    });
    const db = unauthenticated().firestore();
    await assertFails(getDoc(doc(db, "voteEvents/evt-1")));
  });

  test("DENIED: unauthenticated user cannot write voteEvents", async () => {
    const db = unauthenticated().firestore();
    await assertFails(
      setDoc(doc(db, "voteEvents/evt-fake"), {
        eventId: "evt-fake",
        type: "create",
        userId: "alice",
        restaurantId: "hou-1",
        cityId: "houston",
      })
    );
  });

  test("DENIED: authenticated user cannot read voteEvents, including the user the event is about", async () => {
    await seedAsAdmin("voteEvents/evt-1", {
      eventId: "evt-1",
      type: "create",
      userId: "alice",
      restaurantId: "hou-1",
      cityId: "houston",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDoc(doc(db, "voteEvents/evt-1")));
  });

  test("DENIED: authenticated user cannot write voteEvents", async () => {
    const db = freeUser("alice").firestore();
    await assertFails(
      setDoc(doc(db, "voteEvents/evt-fake"), {
        eventId: "evt-fake",
        type: "create",
        userId: "alice",
        restaurantId: "hou-1",
        cityId: "houston",
      })
    );
  });

  test("DENIED: authenticated user cannot list voteEvents", async () => {
    await seedAsAdmin("voteEvents/evt-1", {
      eventId: "evt-1",
      type: "create",
      userId: "alice",
      restaurantId: "hou-1",
      cityId: "houston",
    });
    const db = freeUser("alice").firestore();
    await assertFails(getDocs(collection(db, "voteEvents")));
  });
});
