#!/usr/bin/env node

/**
 * One-off script: reset all vote data to zero for launch.
 *
 * Two operations:
 *   1. Set voteCount = 0 on every restaurant doc.
 *   2. Delete all documents in each restaurant's votes subcollection.
 *
 * Usage:
 *   node scripts/reset_votes.js              # dry run (report only)
 *   node scripts/reset_votes.js --confirm    # live reset
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

  console.log(`\nReset all vote data`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE RESET" : "DRY RUN"}\n`);

  const restaurantsSnap = await db.collection("restaurants").get();

  if (restaurantsSnap.empty) {
    console.log("No restaurant docs found.");
    process.exit(0);
  }

  console.log(`Found ${restaurantsSnap.size} restaurant docs.\n`);

  let totalVoteDocs = 0;
  let totalResetDocs = 0;

  for (const doc of restaurantsSnap.docs) {
    const data = doc.data();
    const currentVoteCount = data.voteCount || 0;

    // Count vote subcollection docs
    const votesSnap = await doc.ref.collection("votes").get();
    const voteDocCount = votesSnap.size;
    totalVoteDocs += voteDocCount;

    const cityId = data.cityId || "unknown";
    console.log(
      `  ${data.name.padEnd(30)} (${cityId}) ` +
        `voteCount=${currentVoteCount}, voteDocs=${voteDocCount}`
    );

    if (confirm) {
      // Reset voteCount field
      if (currentVoteCount !== 0) {
        await doc.ref.update({ voteCount: 0 });
        totalResetDocs++;
      }

      // Delete vote subcollection docs in batches of 500
      if (voteDocCount > 0) {
        const batchSize = 500;
        for (let i = 0; i < votesSnap.docs.length; i += batchSize) {
          const batch = db.batch();
          const slice = votesSnap.docs.slice(i, i + batchSize);
          for (const voteDoc of slice) {
            batch.delete(voteDoc.ref);
          }
          await batch.commit();
        }
      }
    }
  }

  console.log(`\nTotal vote subcollection docs: ${totalVoteDocs}`);

  if (confirm) {
    console.log(`Reset voteCount on ${totalResetDocs} restaurant docs.`);
    console.log(`Deleted ${totalVoteDocs} vote subcollection docs.`);
    console.log("\nDone.\n");
  } else {
    console.log("\nDry run -- no changes. Use --confirm to reset.\n");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
