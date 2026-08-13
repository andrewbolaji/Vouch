#!/usr/bin/env node

/**
 * One-off backfill: set weight = 1 on every existing voteEvents
 * document that predates the weight field.
 *
 * functions/src/vote_audit.ts did not record weight until this
 * change. Every vote cast before it shipped was weight 1 (security
 * rules have always forced weight == 1 on the vote doc itself, see
 * firestore.rules), so backfilling those older events with weight 1
 * is lossless today. It would not be possible to backfill correctly
 * once weighted votes (verified-visit 3x weighting, structurally
 * present but not active per docs/HANDBOOK.md) start shipping,
 * because a missing weight would no longer have a single right
 * answer to fill in.
 *
 * Only touches documents missing the field. Safe to run more than
 * once, and safe to run after new, already-weighted events exist
 * alongside old ones.
 *
 * Usage:
 *   node scripts/backfill_vote_event_weight.js            # dry run
 *   node scripts/backfill_vote_event_weight.js --confirm   # live write
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

  console.log(`\nBackfill voteEvents weight`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  const snap = await db.collection("voteEvents").get();

  if (snap.empty) {
    console.log("No voteEvents docs found.");
    process.exit(0);
  }

  const missing = snap.docs.filter((doc) => doc.data().weight === undefined);

  console.log(`Found ${snap.size} voteEvents docs total.`);
  console.log(`${missing.length} are missing weight.\n`);

  if (confirm && missing.length > 0) {
    for (let i = 0; i < missing.length; i += 500) {
      const batch = db.batch();
      for (const doc of missing.slice(i, i + 500)) {
        batch.update(doc.ref, {weight: 1});
      }
      await batch.commit();
    }
    console.log(`Set weight = 1 on ${missing.length} voteEvents docs.\n`);
  } else if (missing.length > 0) {
    console.log("Dry run -- no writes. Use --confirm to apply.\n");
  } else {
    console.log("Nothing to do, every doc already has weight.\n");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
