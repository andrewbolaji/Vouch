/**
 * Backfills `displayOrder = rank` on every restaurant that lacks it.
 *
 * Why this runs before the recompute is unpaused. Houston and Atlanta
 * carry displayOrder on every document, because they went through
 * set_houston_launch_order.js / set_atlanta_launch_order.js. Chicago,
 * LA and NYC carry it on none. rank_engine.ts :: assignRanks sorts an
 * absent displayOrder last, so running the recompute as things stand
 * reorders those 30 documents. Harmless in itself, nothing there was
 * curated, but it means the run has two effects while only one of them
 * is being measured. The point of that run is the voteCount
 * reconciliation, and a measurement with a second moving part in it is
 * not a measurement.
 *
 * Backfilled first, the recompute preserves every city's current order
 * everywhere and the only delta is voteCount going to zero.
 *
 * It also removes the absent-displayOrder branch from production
 * entirely, so "absent sorts last" becomes a defensive path rather
 * than a live one nobody has watched run.
 *
 * Idempotent. A second run finds nothing to do and writes nothing,
 * because the only documents it touches are ones where the field is
 * absent. It never overwrites an existing displayOrder, including one
 * that disagrees with rank: that disagreement would be a curation
 * decision, and this script is not entitled to overrule it.
 *
 * Dry run by default. --confirm to write.
 *
 *   node backfill_display_order.js
 *   node backfill_display_order.js --confirm
 */

const { initAdminApp, resolvedProjectId } = require("./lib/admin_app");

/** Firestore caps a batch at 500 writes. */
const BATCH_LIMIT = 500;

async function main() {
  const confirm = process.argv.includes("--confirm");
  const app = initAdminApp();
  const projectId = resolvedProjectId(app);
  const db = app.firestore();

  console.log(`Project: ${projectId}`);
  console.log(confirm ? "Mode: APPLY" : "Mode: dry run");
  console.log("");

  const snap = await db.collection("restaurants").get();
  if (snap.empty) {
    console.log("No restaurants found. Nothing to do.");
    return;
  }

  const toWrite = [];
  const skippedNoRank = [];
  const alreadySet = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const has = Object.prototype.hasOwnProperty.call(d, "displayOrder") &&
      typeof d.displayOrder === "number";

    if (has) {
      alreadySet.push({ id: doc.id, cityId: d.cityId, name: d.name,
        rank: d.rank, displayOrder: d.displayOrder });
      continue;
    }

    // rank is the only source for the backfilled value, so a document
    // without a usable one cannot be backfilled and must be reported
    // rather than given a guess.
    if (typeof d.rank !== "number") {
      skippedNoRank.push({ id: doc.id, cityId: d.cityId, name: d.name,
        rank: d.rank });
      continue;
    }

    toWrite.push({ ref: doc.ref, id: doc.id, cityId: d.cityId, name: d.name,
      rank: d.rank });
  }

  const disagree = alreadySet.filter((r) => r.displayOrder !== r.rank);

  console.log(`restaurants:                 ${snap.size}`);
  console.log(`already have displayOrder:   ${alreadySet.length}`);
  console.log(`  of those, != rank:         ${disagree.length} (left alone)`);
  console.log(`to backfill:                 ${toWrite.length}`);
  console.log(`skipped, no usable rank:     ${skippedNoRank.length}`);
  console.log("");

  for (const r of disagree) {
    console.log(`  KEPT ${r.cityId} ${r.name}: displayOrder ` +
      `${r.displayOrder} != rank ${r.rank}, not overwritten`);
  }
  for (const r of skippedNoRank) {
    console.log(`  SKIP ${r.cityId} ${r.name} (${r.id}): rank is ` +
      `${JSON.stringify(r.rank)}`);
  }
  if (disagree.length || skippedNoRank.length) console.log("");

  if (toWrite.length === 0) {
    console.log("Nothing to backfill.");
    return;
  }

  const byCity = new Map();
  for (const r of toWrite) {
    if (!byCity.has(r.cityId)) byCity.set(r.cityId, []);
    byCity.get(r.cityId).push(r);
  }
  for (const cityId of [...byCity.keys()].sort()) {
    const rows = byCity.get(cityId).sort((a, b) => a.rank - b.rank);
    console.log(`${cityId}: ${rows.length}`);
    for (const r of rows) {
      console.log(`  rank ${String(r.rank).padStart(3)} -> displayOrder ` +
        `${String(r.rank).padStart(3)}  ${r.name}`);
    }
  }
  console.log("");

  if (!confirm) {
    console.log("Dry run. No writes. Use --confirm to apply.");
    return;
  }

  let written = 0;
  for (let i = 0; i < toWrite.length; i += BATCH_LIMIT) {
    const chunk = toWrite.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const r of chunk) {
      batch.update(r.ref, { displayOrder: r.rank });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`committed ${written}/${toWrite.length}`);
  }

  // Read back rather than trusting the write. A batch that commits
  // without error still has not been observed to have taken effect.
  const after = await db.collection("restaurants").get();
  const stillMissing = after.docs.filter((doc) => {
    const d = doc.data();
    return !(Object.prototype.hasOwnProperty.call(d, "displayOrder") &&
      typeof d.displayOrder === "number");
  });
  console.log("");
  console.log(`Verified: ${after.size - stillMissing.length}/${after.size} ` +
    "now carry displayOrder.");
  if (stillMissing.length > 0) {
    console.log(`${stillMissing.length} still missing:`);
    for (const doc of stillMissing) {
      console.log(`  ${doc.id} ${doc.data().name}`);
    }
    process.exitCode = 1;
  }
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
