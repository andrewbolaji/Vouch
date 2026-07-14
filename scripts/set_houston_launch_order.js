#!/usr/bin/env node

/**
 * One-off script: set curated launch order on Houston restaurant docs.
 *
 * Sets both `rank` and `displayOrder` to a hardcoded 1..10 order.
 * Matches docs by name within cityId=="houston". If any name fails
 * to match exactly one doc, the script aborts before writing anything.
 *
 * Also deletes Houston docs NOT on the launch list (removals).
 *
 * Usage:
 *   node scripts/set_houston_launch_order.js            # dry run
 *   node scripts/set_houston_launch_order.js --confirm   # live write
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Curated launch order: [rank, name]
const LAUNCH_ORDER = [
  [1, "Mensho"],
  [2, "Tacos Los Brothers"],
  [3, "Crave Suya"],
  [4, "The Peri Peri Factory"],
  [5, "Corkscrew BBQ"],
  [6, "Lost and Found"],
  [7, "Top Sushi"],
  [8, "The Better Box"],
  [9, "Joey Uptown"],
  [10, "Lotus Seafood"],
];

// Restaurants to remove from Houston (not on the new list).
const REMOVALS = [
  "The Puddery",
  "Le Jardinier",
  "Dona Leti's",
  "Hidden Omakase",
  "Tatemo",
  "Taste Bar + Kitchen",
  "Cool Runnings",
];

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nSet Houston launch order`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  // Fetch all Houston restaurant docs
  const snap = await db
    .collection("restaurants")
    .where("cityId", "==", "houston")
    .get();

  if (snap.empty) {
    console.error("ERROR: No Houston restaurant docs found.");
    process.exit(1);
  }

  console.log(`Found ${snap.size} Houston restaurant docs.\n`);

  // Build name -> doc map
  const byName = new Map();
  for (const doc of snap.docs) {
    const name = doc.data().name;
    if (byName.has(name)) {
      console.error(`ERROR: Duplicate name "${name}" in Houston docs.`);
      process.exit(1);
    }
    byName.set(name, doc);
  }

  // For Top Sushi, also try matching "Top Sushi" prefix in case the
  // Firestore doc includes location info in the name.
  // The launch list says "Top Sushi" but the Westheimer location is required.

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

  // Validate removal targets exist
  const removalDocs = [];
  for (const name of REMOVALS) {
    const doc = byName.get(name);
    if (doc) {
      removalDocs.push({ name, doc });
    } else {
      console.warn(`  WARN: Removal target "${name}" not found (already gone?)`);
    }
  }

  // Check for Houston docs that are neither in LAUNCH_ORDER nor REMOVALS
  const launchNames = new Set(LAUNCH_ORDER.map(([, n]) => n));
  const removalNames = new Set(REMOVALS);
  for (const name of byName.keys()) {
    if (!launchNames.has(name) && !removalNames.has(name)) {
      console.warn(
        `  WARN: "${name}" is in Firestore but not in LAUNCH_ORDER or REMOVALS`
      );
    }
  }

  // --- Rank updates ---
  console.log("\nRank assignments:");
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

  // --- Removals ---
  if (removalDocs.length > 0) {
    console.log("\nRemovals:");
    for (const { name, doc } of removalDocs) {
      console.log(`  DEL  ${name.padEnd(25)} (${doc.id})`);
      if (confirm) {
        batch.delete(doc.ref);
      }
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
      .where("cityId", "==", "houston")
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
