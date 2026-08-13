#!/usr/bin/env node

/**
 * Checks whether any vote document's createdAt field disagrees with
 * when Firestore actually created the document.
 *
 * createdAt is client-supplied. firestore.rules constrains it to
 * equal request.time at write time, but that check did not always
 * exist, and an admin script writing directly with the Admin SDK
 * bypasses security rules entirely. Either way, a document already
 * in the database could carry a createdAt that does not match when
 * it was actually written.
 *
 * This is exactly how 163 orphaned seed vote documents were found
 * in production on 2026-08-07 (see the vote data provenance section
 * in README.md). Nobody could check for that without writing a
 * throwaway script first. Now there is one.
 *
 * Usage:
 *   node scripts/check_vote_timestamps.js
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");
const {initAdminApp, resolvedProjectId} = require("./lib/admin_app");

// This script is where the pinning rule was first learned: an earlier
// version relied on ambient project detection, printed "(unknown)"
// for the project, and appeared to succeed with a result of zero
// documents when it may not have reached any project at all. The
// reasoning now lives in lib/admin_app.js, which every script in this
// directory shares, so no script has to remember it individually.
initAdminApp();
const db = admin.firestore();

const DRIFT_THRESHOLD_MS = 60 * 1000;

async function main() {
  const projectId = resolvedProjectId();
  console.log(`\nChecking vote document timestamps`);
  console.log(`Target project: ${projectId}\n`);

  const snap = await db.collectionGroup("votes").get();
  console.log(`Total vote documents: ${snap.size}`);

  let mismatched = 0;
  for (const doc of snap.docs) {
    const createdAt = doc.data().createdAt;
    const createTime = doc.createTime;
    const diffMs =
      createdAt && createTime
        ? Math.abs(createdAt.toMillis() - createTime.toMillis())
        : null;

    if (diffMs === null || diffMs > DRIFT_THRESHOLD_MS) {
      mismatched++;
      const createdAtStr = createdAt ? createdAt.toDate().toISOString() : "(missing)";
      const createTimeStr = createTime ? createTime.toDate().toISOString() : "(missing)";
      console.log(
        `MISMATCH ${doc.ref.path}: createdAt=${createdAtStr} ` +
          `docCreateTime=${createTimeStr} diffMs=${diffMs}`
      );
    }
  }

  console.log(
    `\nMismatched (missing or drifted more than ${DRIFT_THRESHOLD_MS}ms): ${mismatched}`
  );
  process.exit(mismatched > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
