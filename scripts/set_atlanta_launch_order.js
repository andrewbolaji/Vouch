#!/usr/bin/env node

/**
 * One-off script: set curated launch order on Atlanta restaurant docs.
 *
 * Sets both `rank` and `displayOrder` to a hardcoded 1..17 order.
 * Matches docs by name within cityId=="atlanta". If any name fails
 * to match exactly one doc, the script aborts before writing anything.
 *
 * Usage:
 *   node scripts/set_atlanta_launch_order.js            # dry run
 *   node scripts/set_atlanta_launch_order.js --confirm   # live write
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Curated launch order: [rank, name]
const LAUNCH_ORDER = [
  [1, "Poor Calvin's"],
  [2, "Pollo Primo"],
  [3, "Best Wings"],
  [4, "Red Rice"],
  [5, "Pasta da Pulcinella"],
  [6, "Aviva by Kameel"],
  [7, "The Optimist"],
  [8, "Flavor Rich"],
  [9, "Clay's"],
  [10, "Kimball House"],
  [11, "Juci Jerk"],
  [12, "Jamaican Jerk Biz"],
  [13, "The Dining Experience"],
  [14, "La Grotta"],
  [15, "Le Colonial"],
  [16, "The Porter Beer Bar"],
  [17, "La Fonda Latina"],
];

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nSet Atlanta launch order`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  // Fetch all Atlanta restaurant docs
  const snap = await db
    .collection("restaurants")
    .where("cityId", "==", "atlanta")
    .get();

  if (snap.empty) {
    console.error("ERROR: No Atlanta restaurant docs found.");
    process.exit(1);
  }

  console.log(`Found ${snap.size} Atlanta restaurant docs.\n`);

  // Build name -> doc map
  const byName = new Map();
  for (const doc of snap.docs) {
    const name = doc.data().name;
    if (byName.has(name)) {
      console.error(`ERROR: Duplicate name "${name}" in Atlanta docs.`);
      process.exit(1);
    }
    byName.set(name, doc);
  }

  // Validate every name in LAUNCH_ORDER maps to exactly one doc
  const errors = [];
  for (const [rank, name] of LAUNCH_ORDER) {
    if (!byName.has(name)) {
      errors.push(`Rank ${rank}: "${name}" not found in Firestore`);
    }
  }

  if (errors.length > 0) {
    console.error("ERROR: Name mismatches detected. Aborting.\n");
    for (const e of errors) console.error(`  ${e}`);
    console.error("\nAvailable names in Firestore:");
    for (const name of byName.keys()) console.error(`  - ${name}`);
    process.exit(1);
  }

  if (LAUNCH_ORDER.length !== snap.size) {
    console.warn(
      `WARNING: LAUNCH_ORDER has ${LAUNCH_ORDER.length} entries ` +
        `but Firestore has ${snap.size} Atlanta docs.\n`
    );
  }

  // Build batch
  const batch = db.batch();
  for (const [rank, name] of LAUNCH_ORDER) {
    const doc = byName.get(name);
    console.log(
      `  ${String(rank).padStart(2)}. ${name.padEnd(25)} (${doc.id})`
    );
    if (confirm) {
      batch.update(doc.ref, { rank, displayOrder: rank });
    }
  }

  if (confirm) {
    await batch.commit();
    console.log("\nBatch committed.\n");
  } else {
    console.log("\nDry run -- no writes. Use --confirm to apply.\n");
  }

  // Verify: read back and print
  if (confirm) {
    console.log("Verification (reading back from Firestore):\n");
    const verifySnap = await db
      .collection("restaurants")
      .where("cityId", "==", "atlanta")
      .get();

    const sorted = verifySnap.docs
      .map((doc) => doc.data())
      .sort((a, b) => a.rank - b.rank);

    console.log("Rank | displayOrder | Name");
    console.log("-----|-------------|-----------------------------");
    for (const d of sorted) {
      console.log(
        `${String(d.rank).padStart(4)} | ${String(d.displayOrder).padStart(11)} | ${d.name}`
      );
    }
    console.log("");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
