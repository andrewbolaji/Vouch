/**
 * Read-only. Reports whether restaurants carry displayOrder, and
 * whether it agrees with rank.
 *
 * Exists because rank_engine.ts :: assignRanks now breaks ties on
 * displayOrder instead of on name. That fix is worth nothing if the
 * documents it runs against do not carry the field: absent
 * displayOrder sorts last, so a city where none of the documents
 * have it falls straight through to the id tie-break and the curated
 * order is still lost. The fix has to be confirmed against real data,
 * not just against a fixture that sets the field by construction.
 *
 * Writes nothing. Safe to run against production.
 */

const { initAdminApp, resolvedProjectId } = require("./lib/admin_app");

async function main() {
  const app = initAdminApp();
  const projectId = resolvedProjectId(app);
  const db = app.firestore();

  console.log(`Project: ${projectId}`);
  console.log("");

  const snap = await db.collection("restaurants").get();
  if (snap.empty) {
    console.log("No restaurants found. Nothing to check.");
    return;
  }

  const byCity = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    const cityId = d.cityId || "(no cityId)";
    if (!byCity.has(cityId)) byCity.set(cityId, []);
    byCity.get(cityId).push({
      id: doc.id,
      name: d.name,
      rank: d.rank,
      // Distinguish absent from 0. Both are falsy, and they mean
      // opposite things to assignRanks: absent sorts last, 0 sorts
      // first.
      hasDisplayOrder: Object.prototype.hasOwnProperty.call(d, "displayOrder"),
      displayOrder: d.displayOrder,
    });
  }

  let totalMissing = 0;
  let totalDocs = 0;

  for (const cityId of [...byCity.keys()].sort()) {
    const rows = byCity.get(cityId).sort((a, b) => {
      const ar = typeof a.rank === "number" ? a.rank : Infinity;
      const br = typeof b.rank === "number" ? b.rank : Infinity;
      return ar - br;
    });

    const missing = rows.filter((r) => !r.hasDisplayOrder);
    const nullish = rows.filter(
      (r) => r.hasDisplayOrder && (r.displayOrder === null ||
        r.displayOrder === undefined)
    );
    const disagree = rows.filter(
      (r) => r.hasDisplayOrder && typeof r.displayOrder === "number" &&
        r.displayOrder !== r.rank
    );

    totalMissing += missing.length + nullish.length;
    totalDocs += rows.length;

    console.log(`${cityId}: ${rows.length} restaurants`);
    console.log(`  missing displayOrder: ${missing.length + nullish.length}`);
    console.log(`  displayOrder !== rank: ${disagree.length}`);
    console.log("  rank | displayOrder | name");
    for (const r of rows) {
      const dispVal = r.hasDisplayOrder ?
        String(r.displayOrder) :
        "ABSENT";
      const flag = r.hasDisplayOrder && r.displayOrder === r.rank ? "" : "  <-";
      console.log(
        `  ${String(r.rank).padStart(4)} | ${dispVal.padStart(12)} | ` +
        `${r.name}${flag}`
      );
    }
    console.log("");
  }

  console.log(`Total: ${totalDocs} restaurants, ${totalMissing} without a ` +
    "usable displayOrder.");
  if (totalMissing > 0) {
    console.log("");
    console.log("Those documents sort LAST on the assignRanks tie-break, " +
      "behind every");
    console.log("document that has one. Run the launch-order script for " +
      "the affected city");
    console.log("before relying on the tie-break to hold a curated order.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
