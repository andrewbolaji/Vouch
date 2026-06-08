#!/usr/bin/env node

/**
 * Houston seed pipeline: enrich candidates via Google Places and seed to
 * production Firestore.
 *
 * Usage:
 *   # Dry run (default): shows what would be created/updated/cleaned
 *   node scripts/seed_houston.js
 *
 *   # Clean demo data from prior seed_production.js
 *   node scripts/seed_houston.js --clean-demo --confirm
 *
 *   # Write enriched Houston data to prod
 *   node scripts/seed_houston.js --confirm
 *
 * Requires:
 *   - GOOGLE_PLACES_API_KEY env var (for Places enrichment)
 *   - Application Default Credentials for Firestore admin access
 *     (gcloud auth application-default login, or GOOGLE_APPLICATION_CREDENTIALS)
 *   - data/houston_candidates_seedready.csv in the project root
 *
 * NEVER call this from client code. One-time admin operation.
 */

const path = require("path");
const admin = require("firebase-admin");
const { parseCsv } = require("./lib/csv_parser");
const { enrichCandidates } = require("./lib/places_enricher");
const {
  scanDemoData,
  cleanDemoData,
  writeHoustonData,
} = require("./lib/firestore_writer");

// Initialize Firebase Admin with default credentials
admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const cleanDemo = args.includes("--clean-demo");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nHouston seed pipeline`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  // 1. Scan for demo data
  console.log("Scanning for demo data...");
  const demoData = await scanDemoData(db);
  const demoTotal =
    demoData.demoCities.length +
    demoData.demoRestaurants.length +
    demoData.demoNotes.length;

  if (demoTotal > 0) {
    console.log(`Found ${demoTotal} demo documents in prod.`);
    if (cleanDemo) {
      await cleanDemoData(db, demoData, confirm);
    } else {
      console.log("Use --clean-demo to remove them.\n");
    }
  } else {
    console.log("No demo data found.\n");
  }

  // 2. Parse CSV
  const csvPath = path.resolve(__dirname, "../data/houston_candidates_seedready.csv");
  console.log(`Parsing CSV: ${csvPath}`);
  let candidates;
  try {
    candidates = parseCsv(csvPath);
  } catch (err) {
    console.error(`CSV parse error: ${err.message}`);
    process.exit(1);
  }
  console.log(`Parsed ${candidates.length} candidates.\n`);

  // 3. Enrich via Google Places
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    console.error("ERROR: GOOGLE_PLACES_API_KEY env var is not set.");
    console.error("Set it to run Places enrichment.");
    process.exit(1);
  }

  console.log("Enriching via Google Places API...\n");
  const { enriched, manualReview, callCount } = await enrichCandidates(
    candidates,
    apiKey
  );

  console.log(`\nEnrichment complete:`);
  console.log(`  Places API calls: ${callCount}`);
  console.log(`  Enriched:         ${enriched.length}`);
  console.log(`  Manual review:    ${manualReview.length}\n`);

  if (manualReview.length > 0) {
    console.log("=== MANUAL REVIEW LIST ===");
    for (const r of manualReview) {
      console.log(`  ${r.name} | ${r.reason}`);
    }
    console.log("");
  }

  // 4. Write to Firestore
  if (enriched.length === 0) {
    console.log("No enriched candidates to write.");
    process.exit(0);
  }

  console.log("Writing to Firestore...");
  const { created, updated, skipped } = await writeHoustonData(
    db,
    FieldValue,
    enriched,
    confirm
  );

  console.log(`\nSummary:`);
  console.log(`  Created: ${created}`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped: ${skipped}`);

  if (!confirm) {
    console.log(
      "\nThis was a dry run. To execute, run with --confirm:\n" +
        "  node scripts/seed_houston.js --confirm\n"
    );
  } else {
    console.log("\nDone. Houston data seeded.");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Seed script failed:", err);
  process.exit(1);
});
