#!/usr/bin/env node

/**
 * One-time backfill: set commentCount on each restaurant doc
 * by counting its comments subcollection.
 *
 * Matches every other script in this directory: plain
 * initializeApp() so Application Default Credentials resolve both
 * project and credentials the same way, the resolved project
 * printed up front so a human can check it before confirming, and
 * --confirm required to write. This used to special-case
 * GOOGLE_APPLICATION_CREDENTIALS and fall back to a hardcoded
 * "vouch-dev" project otherwise, which meant a real prod credential
 * wrote immediately with no gate, and an unset one silently
 * redirected to a dev project instead of surfacing the ambiguity.
 * Neither failure mode exists once the project is always visible
 * and a write always needs --confirm.
 *
 * Usage:
 *   node scripts/backfill_comment_counts.js            # dry run
 *   node scripts/backfill_comment_counts.js --confirm   # live write
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nBackfill comment counts`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  const restaurants = await db.collection("restaurants").get();

  if (restaurants.empty) {
    console.log("No restaurant docs found.");
    process.exit(0);
  }

  let updated = 0;

  for (const snap of restaurants.docs) {
    const comments = await snap.ref.collection("comments").count().get();
    const count = comments.data().count;
    const current = snap.data().commentCount;
    console.log(
      `  ${snap.id}: commentCount ${current ?? "(unset)"} -> ${count}`
    );
    if (confirm) {
      await snap.ref.update({commentCount: count});
    }
    updated++;
  }

  if (confirm) {
    console.log(`\nUpdated ${updated} restaurant(s).\n`);
  } else {
    console.log(`\nDry run -- no writes. Use --confirm to apply.\n`);
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
