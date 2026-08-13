#!/usr/bin/env node

/**
 * Rebuilds every user's votedRestaurantIds from the votes
 * subcollections, which are the source of truth.
 *
 * users/{uid}.votedRestaurantIds is a denormalized convenience list:
 * the client reads it once on sign-in to know which vote buttons to
 * fill in, instead of one read per restaurant in the catalogue. It
 * is maintained by the onVoteCreated / onVoteDeleted triggers. This
 * script is what closes the two gaps that maintenance cannot:
 *
 *   1. Votes cast before those triggers were deployed, which no
 *      trigger ever saw and nothing else will ever backfill.
 *   2. Divergence after the fact. arrayUnion and arrayRemove are
 *      idempotent under redelivery but not order-independent, and
 *      Firestore trigger delivery is unordered, so a fast vote then
 *      unvote whose events land reversed converges to the wrong
 *      answer. The client repairs a restaurant it is looking at
 *      (AppState.repairVoteStateForRestaurant), which covers what a
 *      user can see; this covers the rest.
 *
 * Against production today this is a no-op: there are zero vote
 * documents. That is the point of writing it now rather than when it
 * is first needed, which would be during an incident.
 *
 * Rebuilds from scratch rather than merging into what is already
 * there, so a stale ID that no longer has a vote document is removed
 * rather than preserved. Writes id alongside the list: nothing
 * requires a profile document to exist before its owner votes, so
 * this script can be what creates one, and a profile without id
 * fails firestore.rules' id comparison on every later client update,
 * locking the owner out of their own document.
 *
 * Usage:
 *   node scripts/backfill_voted_restaurant_ids.js            # dry run
 *   node scripts/backfill_voted_restaurant_ids.js --confirm   # live write
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

// Pinned explicitly rather than left to ambient project detection,
// for the reason recorded in check_vote_timestamps.js: a
// collectionGroup query with no resolvable project either throws or
// reports zero documents, and zero is the answer this script expects
// today, so an unresolved project would be indistinguishable from a
// clean result. Trust the counts below only if the project printed
// above them is not "(unknown)".
const PROJECT_ID = "majorcitymusteats";

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nBackfill votedRestaurantIds from vote documents`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  const votesSnap = await db.collectionGroup("votes").get();
  console.log(`Found ${votesSnap.size} vote doc(s) total.`);

  // Vote doc ID is the voter's uid; its grandparent is the restaurant.
  const byUser = new Map();
  let skippedOrphans = 0;

  for (const voteDoc of votesSnap.docs) {
    const restaurantRef = voteDoc.ref.parent.parent;
    if (!restaurantRef) {
      skippedOrphans++;
      continue;
    }
    const uid = voteDoc.id;
    if (!byUser.has(uid)) byUser.set(uid, new Set());
    byUser.get(uid).add(restaurantRef.id);
  }

  if (skippedOrphans > 0) {
    console.log(
      `Skipped ${skippedOrphans} vote doc(s) with no parent restaurant.`
    );
  }
  console.log(`Covering ${byUser.size} user(s).\n`);

  if (byUser.size === 0) {
    console.log("Nothing to backfill.\n");
    process.exit(0);
  }

  let written = 0;
  const entries = [...byUser.entries()];

  for (let i = 0; i < entries.length; i += 500) {
    const slice = entries.slice(i, i + 500);
    const batch = db.batch();

    for (const [uid, restaurantIds] of slice) {
      const ids = [...restaurantIds].sort();
      console.log(`  ${uid}: ${ids.length} vote(s) -> ${ids.join(", ")}`);
      if (confirm) {
        batch.set(
          db.collection("users").doc(uid),
          {id: uid, votedRestaurantIds: ids},
          {merge: true}
        );
      }
      written++;
    }

    if (confirm) await batch.commit();
  }

  if (confirm) {
    console.log(`\nRewrote votedRestaurantIds on ${written} user doc(s).\n`);
  } else {
    console.log(`\nDry run -- no writes. Use --confirm to apply.\n`);
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
