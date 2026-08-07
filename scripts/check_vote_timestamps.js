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

// Pinned explicitly rather than left to ambient project detection
// (GCLOUD_PROJECT, gcloud config, metadata server). An earlier version
// of this script relied on that detection, printed "(unknown)" for the
// project, and appeared to succeed with a result of zero documents
// when it may not have reached any project at all. Trust the number
// this script prints only if the project name above it is not "(unknown)".
const PROJECT_ID = "majorcitymusteats";

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const DRIFT_THRESHOLD_MS = 60 * 1000;

async function main() {
  const projectId = admin.app().options.projectId || "(unknown)";
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
