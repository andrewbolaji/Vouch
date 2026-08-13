/**
 * Deletes every scaffold-authored narrative field, and rewrites
 * Houston's descriptions to a minimal verifiable shape.
 *
 * WHY THE DISQUALIFIER IS PROVENANCE, NOT ACCURACY.
 *
 * The 40 descriptions and 40 vibeTags on Houston, Chicago, LA and NYC
 * all come from hardcoded arrays in scripts/seed_production.js,
 * introduced by 162b12b as Block 0 scaffold. They were audited, and
 * the audit found five outright falsehoods, including telling users
 * in the present perfect that Dom DeMarco, who died on 17 March 2022,
 * is hand-cutting basil onto their pizza.
 *
 * It also found the opposite. Of seven claims flagged as suspected
 * fabrications, four were true, including CorkScrew BBQ's Michelin
 * star, which is real: inaugural MICHELIN Guide Texas, 11 November
 * 2024. A scaffold that generates plausible text sometimes generates
 * true text.
 *
 * That is the argument FOR deleting all 40, not against it. Nobody at
 * Vouch knows which paragraphs are accurate. A stopped clock is right
 * twice a day and you still do not use it to tell the time. Repairing
 * the flagged claims would leave 28 paragraphs of unsourced copy that
 * merely have no falsifiable claim in them yet, plus a maintenance
 * story in which the next person assumes the survivors were checked.
 *
 * So the population goes, and verified facts are re-added
 * deliberately, one at a time, by a human who checked.
 *
 * WHAT IS NOT TOUCHED. Atlanta's 17, which have no description and no
 * vibeTags to begin with, and whose data came through a human-sourced
 * candidate list enriched by Google Places. And every structured
 * field everywhere: name, cuisine, rank, locations, priceLevel,
 * openingHours, placeId. This script only removes prose.
 *
 * HOUSTON IS REWRITTEN RATHER THAN EMPTIED, because it is the launch
 * city. Each replacement is composed ONLY from fields already on the
 * same document (cuisine, the location's own area name, and
 * isMobileVenue). Nothing is authored here and no new claim is made.
 * The one exception is noted inline and was independently verified
 * twice.
 *
 * Note for Andrew: because these are composed from cuisine and
 * neighbourhood, they are now largely redundant with the structured
 * fields the UI already has. Emptying them and letting the UI compose
 * the same line is a defensible alternative, and would leave the
 * voice entirely in the insider note where you are the speaker.
 *
 * Dry run by default. --confirm to write.
 */

const admin = require("firebase-admin");
const { initAdminApp, resolvedProjectId } = require("./lib/admin_app");

/** Cities whose narrative fields came from the Block 0 scaffold. */
const SCAFFOLD_CITIES = new Set(["houston", "chicago", "la", "nyc"]);

/** Never touched. No narrative fields, different provenance. */
const HELD_CITIES = new Set(["atlanta"]);

/**
 * Houston replacements, keyed by document id.
 *
 * Every one restates cuisine, neighbourhood and service style, all of
 * which are already on the document as structured fields. No claim
 * here is new.
 *
 * hou-9 is the single exception and the only verified fact carried
 * forward from the scaffold. CorkScrew BBQ received a MICHELIN star
 * in the inaugural Guide Texas, announced 11 November 2024, one of
 * four Texas barbecue restaurants to do so. Checked against sources
 * during the audit and independently verified by Andrew before this
 * ran. It is in the app because two people checked it, not because a
 * scaffold guessed right.
 */
const HOUSTON_DESCRIPTIONS = {
  "hou-1": "Ramen. Chinatown.",
  "hou-11": "Tacos. Food truck in South Main.",
  "hou-12": "West African. Food truck on Richmond Ave.",
  "hou-13": "Peri peri chicken. Westheimer.",
  "hou-9": "Barbecue in Spring. Awarded a MICHELIN star in the " +
    "inaugural MICHELIN Guide Texas, November 2024.",
  "hou-4": "Cocktail bar and kitchen. Midtown.",
  "hou-14": "Sushi. Westheimer.",
  "hou-15": "Comfort food. Food truck in Cypress Creek.",
  "hou-16": "New American. Galleria.",
  "hou-17": "Cajun seafood. Southwest Freeway.",
};

async function main() {
  const confirm = process.argv.includes("--confirm");
  const app = initAdminApp();
  const projectId = resolvedProjectId(app);
  const db = app.firestore();

  console.log(`Project: ${projectId}`);
  console.log(confirm ? "Mode: WRITE" : "Mode: dry run");
  console.log("");

  const snap = await db.collection("restaurants").get();
  const updates = [];
  const skippedHeld = [];
  const unknownCity = [];
  const houstonMissing = [];

  for (const doc of snap.docs) {
    const d = doc.data();

    if (HELD_CITIES.has(d.cityId)) { skippedHeld.push(d.name); continue; }
    if (!SCAFFOLD_CITIES.has(d.cityId)) { unknownCity.push(d); continue; }

    const isHouston = d.cityId === "houston";
    let newDescription = "";

    if (isHouston) {
      const replacement = HOUSTON_DESCRIPTIONS[doc.id];
      // A Houston document with no prepared replacement is not
      // something to guess at, and emptying it silently would be a
      // different decision than the one approved.
      if (replacement === undefined) { houstonMissing.push(doc.id); continue; }
      newDescription = replacement;
    }

    updates.push({
      ref: doc.ref, id: doc.id, cityId: d.cityId, rank: d.rank,
      name: d.name,
      oldDescription: d.description || "",
      newDescription,
      oldTags: d.vibeTags || [],
    });
  }

  if (unknownCity.length > 0) {
    console.error("ERROR: restaurant in a city on neither list. Aborting.");
    for (const d of unknownCity) console.error(`  ${d.cityId} ${d.name}`);
    process.exit(1);
  }
  if (houstonMissing.length > 0) {
    console.error("ERROR: Houston document with no prepared replacement. " +
      "Aborting rather than emptying it.");
    for (const id of houstonMissing) console.error(`  ${id}`);
    process.exit(1);
  }

  let tagsRemoved = 0;
  for (const u of updates) tagsRemoved += u.oldTags.length;

  console.log(`restaurants:              ${snap.size}`);
  console.log(`  scaffold, to update:    ${updates.length}`);
  console.log(`  atlanta, untouched:     ${skippedHeld.length}`);
  console.log(`vibeTags to remove:       ${tagsRemoved}`);
  console.log("");

  for (const u of updates.sort((a, b) =>
    a.cityId.localeCompare(b.cityId) || a.rank - b.rank)) {
    console.log(`${u.cityId} r${u.rank} ${u.name}`);
    console.log(`  was: ${JSON.stringify(u.oldDescription)}`);
    console.log(`  now: ${JSON.stringify(u.newDescription)}`);
    console.log(`  tags removed: ${JSON.stringify(u.oldTags)}`);
  }
  console.log("");

  if (!confirm) {
    console.log("Dry run. Nothing written. Use --confirm to apply.");
    return;
  }

  const batch = db.batch();
  for (const u of updates) {
    batch.update(u.ref, {
      description: u.newDescription,
      vibeTags: [],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Committed ${updates.length} updates.`);

  // Read back rather than trusting the batch.
  const after = await db.collection("restaurants").get();
  let strayTags = 0, strayProse = 0, atlantaChanged = 0;
  for (const doc of after.docs) {
    const d = doc.data();
    if (HELD_CITIES.has(d.cityId)) {
      if ((d.description || "") !== "" || (d.vibeTags || []).length) {
        atlantaChanged++;
      }
      continue;
    }
    if ((d.vibeTags || []).length > 0) strayTags++;
    const expected = d.cityId === "houston" ?
      (HOUSTON_DESCRIPTIONS[doc.id] || "") : "";
    if ((d.description || "") !== expected) strayProse++;
  }
  console.log("");
  console.log(`Verified: ${strayTags} scaffold docs still carry vibeTags ` +
    "(expected 0)");
  console.log(`Verified: ${strayProse} scaffold docs have an unexpected ` +
    "description (expected 0)");
  console.log(`Verified: ${atlantaChanged} atlanta docs changed (expected 0)`);
  if (strayTags || strayProse || atlantaChanged) process.exitCode = 1;
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((err) => { console.error(err); process.exit(1); });
