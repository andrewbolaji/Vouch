/**
 * Deletes the insider notes that came from the Block 0 scaffold.
 *
 * Why they are being deleted rather than displayed. All 33 notes on
 * Houston, Chicago, LA and NYC restaurants originate in one hardcoded
 * object at scripts/seed_production.js:91, introduced by commit
 * 162b12b (2026-05-07), whose own message describes it as scaffold:
 * "Block 0: Full UI layer, 4 providers, seed data, 100
 * interaction/unit/smoke tests."
 *
 * They read as generated rather than observed, and one is provable
 * rather than a matter of taste: hou-4's tip, "The patio with the
 * downtown skyline view is the spot", paraphrases the description
 * three lines above it in the same file, "a downtown-view patio".
 * That is text derived from adjacent text.
 *
 * The product's entire claim is that a local told you something true.
 * Publishing 33 generated tips about real, named, operating
 * businesses under that banner is not a quality problem, it is the
 * claim being false.
 *
 * Andrew will verify and write real ones. Until then the correct
 * state is empty, because nothing true has been written yet, rather
 * than full of things nobody said.
 *
 * SCOPE. This deletes notes for the four scaffold cities only. It
 * does NOT touch Atlanta's 17, which have a different and
 * defensible provenance: data/atlanta_candidates_seedready.csv, a
 * human-sourced candidate list (docs/DECISIONS.md, 2026-05-09,
 * "TikTok food creator candidates + Reddit + Eater + Michelin
 * pipeline. Andrew sources Top 10 candidates per city"), enriched
 * through the Google Places API. Those are held pending Andrew's
 * decision and are listed but skipped by this script.
 *
 * Deleting from Firestore alone is not sufficient. seed_production.js
 * rewrites the same object at line 206, so a later
 * `--force --confirm` run would restore every one of them. The
 * hardcoded object is emptied in the same commit as this script.
 *
 * Dry run by default. --confirm to delete.
 */

const { initAdminApp, resolvedProjectId } = require("./lib/admin_app");

/**
 * Cities whose notes came from the Block 0 scaffold object.
 * Named explicitly rather than derived, so adding a city later
 * cannot silently widen a destructive operation.
 */
const SCAFFOLD_CITIES = new Set(["houston", "chicago", "la", "nyc"]);

/** Held pending a decision, deliberately not deleted. */
const HELD_CITIES = new Set(["atlanta"]);

async function main() {
  const confirm = process.argv.includes("--confirm");
  const app = initAdminApp();
  const projectId = resolvedProjectId(app);
  const db = app.firestore();

  console.log(`Project: ${projectId}`);
  console.log(confirm ? "Mode: DELETE" : "Mode: dry run");
  console.log("");

  const snap = await db.collection("restaurants").get();
  const toDelete = [];
  const held = [];
  const unknownCity = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const notesRef = doc.ref.collection("insiderNotes").doc("notes");
    const notes = await notesRef.get();
    if (!notes.exists) continue;

    const row = { ref: notesRef, id: doc.id, cityId: d.cityId,
      rank: d.rank, name: d.name, data: notes.data() };

    if (SCAFFOLD_CITIES.has(d.cityId)) toDelete.push(row);
    else if (HELD_CITIES.has(d.cityId)) held.push(row);
    // A city in neither set is not something to guess about.
    else unknownCity.push(row);
  }

  console.log(`notes documents found: ` +
    `${toDelete.length + held.length + unknownCity.length}`);
  console.log(`  to delete (scaffold): ${toDelete.length}`);
  console.log(`  held (atlanta):       ${held.length}`);
  console.log(`  unrecognised city:    ${unknownCity.length}`);
  console.log("");

  if (unknownCity.length > 0) {
    console.error("ERROR: notes found on a city in neither list. " +
      "Aborting rather than guessing.");
    for (const r of unknownCity) {
      console.error(`  ${r.cityId} ${r.name} (${r.id})`);
    }
    process.exit(1);
  }

  for (const r of toDelete.sort((a, b) =>
    a.cityId.localeCompare(b.cityId) || a.rank - b.rank)) {
    console.log(`  DELETE ${r.cityId} r${r.rank} ${r.name}`);
    console.log(`         tip:   ${JSON.stringify(r.data.insiderTip)}`);
    console.log(`         order: ${JSON.stringify(r.data.whatToOrder)}`);
  }
  console.log("");
  console.log(`Held, not touched: ${held.length} atlanta notes.`);
  console.log("");

  if (!confirm) {
    console.log("Dry run. Nothing deleted. Use --confirm to delete.");
    return;
  }

  let done = 0;
  for (const r of toDelete) {
    await r.ref.delete();
    done++;
  }
  console.log(`Deleted ${done}.`);

  // Read back rather than trusting the deletes.
  let remaining = 0;
  const after = await db.collection("restaurants").get();
  for (const doc of after.docs) {
    const n = await doc.ref.collection("insiderNotes").doc("notes").get();
    if (n.exists) remaining++;
  }
  console.log(`Verified: ${remaining} notes documents remain ` +
    `(expected ${held.length}, the held atlanta set).`);
  if (remaining !== held.length) process.exitCode = 1;
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
