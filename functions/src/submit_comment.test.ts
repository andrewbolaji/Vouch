/**
 * Tests for the submitComment callable.
 *
 * In its own file, separate from index.test.ts. Calling
 * submitComment.run() directly (rather than reimplementing its
 * logic, the way the existing submitSuggestion tests do) requires
 * importing index.ts, which runs its own unguarded initializeApp()
 * at module scope. index.test.ts already initializes its own app for
 * every other suite in that file; importing index.ts there too would
 * either throw on the second initializeApp() call or, if guarded,
 * leave the app's project id decided by whichever import happened to
 * run first. Keeping this in its own file gives it a fresh module
 * registry, and therefore its own single initializeApp() call, with
 * no effect on index.test.ts's suites.
 */

import {getApps, deleteApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import type {DecodedIdToken} from "firebase-admin/auth";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

// eslint-disable-next-line import/first
import {submitComment} from "./index";

const db = getFirestore();

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/**
 * Deletes every top-level document and, critically, everything under
 * it. Deleting a document does not delete its subcollections, and
 * this suite writes comments as a subcollection of a restaurant doc
 * across several tests in the same file, so a shallow top-level-only
 * clear leaves earlier tests' comments to leak into later ones.
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

type Auth = ReturnType<typeof authFor>;

/**
 * Builds an auth context for a CallableRequest.
 * @param {string} uid The authenticated user's uid.
 * @param {string} membershipTier The membershipTier claim to simulate.
 * @return {object} An auth object shaped like CallableRequest's.
 */
function authFor(uid: string, membershipTier = "free") {
  return {
    uid,
    token: {membershipTier} as unknown as DecodedIdToken,
    rawToken: "",
  };
}

/**
 * Builds a full CallableRequest. submitComment.run() (used for direct,
 * emulator-backed testing instead of a reimplementation) requires the
 * complete interface, including fields no test here cares about.
 * @param {unknown} data The callable's data payload.
 * @param {Auth} auth Auth context, or undefined for unauthenticated.
 * @return {object} A full CallableRequest, cast loosely for test use.
 */
function request(data: unknown, auth: Auth | undefined) {
  return {
    data,
    auth,
    rawRequest: {} as never,
    acceptsStreaming: false,
  };
}

describe("submitComment", () => {
  const uid = "commenter-1";

  beforeEach(async () => {
    await clearFirestore();
    await db.collection("users").doc(uid).set({
      id: uid,
      displayName: "TestUser",
      email: "test@example.com",
      membershipTier: "free",
    });
    await db
      .collection("restaurants")
      .doc("sc-r1")
      .set({id: "sc-r1", rank: 1});
  });

  test("creates a comment, returns id/createdAt/userName/isInsider",
    async () => {
      const result = await submitComment.run(
        request({restaurantId: "sc-r1", text: "Great food!"}, authFor(uid))
      );

      expect(result.id).toBeTruthy();
      expect(result.userName).toBe("TestUser");
      expect(result.isInsider).toBe(false);
      expect(Number.isNaN(new Date(result.createdAt).getTime())).toBe(false);

      const doc = await db
        .collection("restaurants")
        .doc("sc-r1")
        .collection("comments")
        .doc(result.id)
        .get();
      expect(doc.exists).toBe(true);
      expect(doc.data()?.text).toBe("Great food!");
      expect(doc.data()?.userId).toBe(uid);
    });

  test("rejects with a distinct code when the user has no displayName",
    async () => {
      await db.collection("users").doc(uid).set({
        id: uid,
        email: "test@example.com",
        membershipTier: "free",
      });

      await expect(
        submitComment.run(
          request({restaurantId: "sc-r1", text: "Hello"}, authFor(uid))
        )
      ).rejects.toMatchObject({code: "aborted"});

      const comments = await db
        .collection("restaurants")
        .doc("sc-r1")
        .collection("comments")
        .get();
      expect(comments.size).toBe(0);
    });

  test("rejects with a distinct code when displayName is empty after " +
    "trimming", async () => {
    await db.collection("users").doc(uid).set({
      id: uid,
      displayName: "   ",
      email: "test@example.com",
      membershipTier: "free",
    });

    await expect(
      submitComment.run(
        request({restaurantId: "sc-r1", text: "Hello"}, authFor(uid))
      )
    ).rejects.toMatchObject({code: "aborted"});
  });

  test("derives isInsider from the token claim, not client input", async () => {
    const result = await submitComment.run(
      request(
        {restaurantId: "sc-r1", text: "Insider comment", isInsider: true},
        authFor(uid, "free")
      )
    );
    expect(result.isInsider).toBe(false);
  });

  test("derives userName from the user doc, not client input", async () => {
    const result = await submitComment.run(
      request(
        {
          restaurantId: "sc-r1",
          text: "Impersonation attempt",
          userName: "Admin",
        },
        authFor(uid)
      )
    );
    expect(result.userName).toBe("TestUser");

    const doc = await db
      .collection("restaurants")
      .doc("sc-r1")
      .collection("comments")
      .doc(result.id)
      .get();
    expect(doc.data()?.userName).toBe("TestUser");
  });

  test("cityInsider claim produces isInsider true", async () => {
    const result = await submitComment.run(
      request(
        {restaurantId: "sc-r1", text: "Insider comment"},
        authFor(uid, "cityInsider")
      )
    );
    expect(result.isInsider).toBe(true);
  });

  test("rejects a banned comment, failed-precondition, no write", async () => {
    await expect(
      submitComment.run(
        request(
          {restaurantId: "sc-r1", text: "you are a worthless piece of shit"},
          authFor(uid)
        )
      )
    ).rejects.toMatchObject({code: "failed-precondition"});

    const comments = await db
      .collection("restaurants")
      .doc("sc-r1")
      .collection("comments")
      .get();
    expect(comments.size).toBe(0);
  });

  test("rejects when unauthenticated", async () => {
    await expect(
      submitComment.run(
        request({restaurantId: "sc-r1", text: "hi"}, undefined)
      )
    ).rejects.toMatchObject({code: "unauthenticated"});
  });

  test("rejects empty text", async () => {
    await expect(
      submitComment.run(
        request({restaurantId: "sc-r1", text: ""}, authFor(uid))
      )
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("rejects text over 500 characters", async () => {
    await expect(
      submitComment.run(
        request({restaurantId: "sc-r1", text: "x".repeat(501)}, authFor(uid))
      )
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("a reply carries parentId through the same gate", async () => {
    const parent = await submitComment.run(
      request({restaurantId: "sc-r1", text: "Parent comment"}, authFor(uid))
    );
    const reply = await submitComment.run(
      request(
        {restaurantId: "sc-r1", text: "A reply", parentId: parent.id},
        authFor(uid)
      )
    );

    const doc = await db
      .collection("restaurants")
      .doc("sc-r1")
      .collection("comments")
      .doc(reply.id)
      .get();
    expect(doc.data()?.parentId).toBe(parent.id);
  });

  test("a banned reply is rejected the same way, no write", async () => {
    const parent = await submitComment.run(
      request({restaurantId: "sc-r1", text: "Parent comment"}, authFor(uid))
    );

    await expect(
      submitComment.run(
        request(
          {
            restaurantId: "sc-r1",
            text: "kill yourself",
            parentId: parent.id,
          },
          authFor(uid)
        )
      )
    ).rejects.toMatchObject({code: "failed-precondition"});

    const replies = await db
      .collection("restaurants")
      .doc("sc-r1")
      .collection("comments")
      .where("parentId", "==", parent.id)
      .get();
    expect(replies.size).toBe(0);
  });
});
