#!/usr/bin/env node

/**
 * One-off scan: find vote and comment documents whose parent
 * restaurant no longer exists.
 *
 * This is the same shape of problem that produced the 163 orphaned
 * vote documents found in production on 2026-08-07 (restaurant docs
 * deleted without walking their votes subcollection first, see
 * scripts/lib/cascade_delete.js and functions/src/index.ts's
 * onRestaurantDeleted trigger for the fix going forward). This scan
 * finds anything orphaned before that fix existed, or by any path
 * that still bypasses it.
 *
 * Reports counts per collection, grouped by the restaurantId they
 * point at. Dry run by default; --confirm deletes what it finds.
 *
 * Usage:
 *   node scripts/scan_orphaned_docs.js              # dry run (report only)
 *   node scripts/scan_orphaned_docs.js --confirm    # delete orphans found
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Scans a collection group for docs whose parent restaurant is
 * missing.
 * @param {string} groupName "votes" or "comments".
 * @returns {Promise<Map<string, FirebaseFirestore.QueryDocumentSnapshot[]>>}
 *   Orphaned docs grouped by the restaurantId they point at.
 */
async function findOrphans(groupName) {
  const snap = await db.collectionGroup(groupName).get();
  const byRestaurant = new Map();

  // Cache restaurant existence checks; the same restaurantId can
  // show up under many orphaned vote/comment docs.
  const existsCache = new Map();

  for (const doc of snap.docs) {
    const restaurantRef = doc.ref.parent.parent;
    if (!restaurantRef) continue; // not actually under a restaurant
    const restaurantId = restaurantRef.id;

    if (!existsCache.has(restaurantId)) {
      const restaurantSnap = await restaurantRef.get();
      existsCache.set(restaurantId, restaurantSnap.exists);
    }

    if (!existsCache.get(restaurantId)) {
      if (!byRestaurant.has(restaurantId)) {
        byRestaurant.set(restaurantId, []);
      }
      byRestaurant.get(restaurantId).push(doc);
    }
  }

  return byRestaurant;
}

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nScan for orphaned votes and comments`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE DELETE" : "DRY RUN"}\n`);

  for (const groupName of ["votes", "comments"]) {
    const orphans = await findOrphans(groupName);
    const totalDocs = [...orphans.values()].reduce(
      (sum, docs) => sum + docs.length,
      0
    );

    console.log(
      `${groupName}: ${totalDocs} orphaned doc(s) across ` +
        `${orphans.size} missing restaurant(s)`
    );

    for (const [restaurantId, docs] of orphans) {
      console.log(`  ${restaurantId}: ${docs.length} ${groupName} doc(s)`);
      if (confirm) {
        // Delete exactly the orphaned docs found above, in batches
        // of 500, not a fresh query, in case something else wrote to
        // this subcollection between the scan and this delete.
        let deleted = 0;
        for (let i = 0; i < docs.length; i += 500) {
          const batch = db.batch();
          for (const doc of docs.slice(i, i + 500)) {
            batch.delete(doc.ref);
          }
          await batch.commit();
          deleted += Math.min(500, docs.length - i);
        }
        console.log(`    deleted ${deleted}`);
      }
    }
    console.log("");
  }

  if (!confirm) {
    console.log("Dry run -- no deletes. Use --confirm to remove orphans.\n");
  } else {
    console.log("Done.\n");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
