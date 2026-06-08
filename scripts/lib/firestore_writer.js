/**
 * Firestore writer module for the Houston seed pipeline.
 *
 * Writes city and restaurant docs idempotently:
 * - Match on placeId (doc ID includes placeId).
 * - Existing docs are updated (priceLevel, locations, openingHours, updatedAt).
 * - voteCount, rank, and user-generated data are NOT overwritten.
 * - Dry-run by default; requires --confirm flag to write.
 *
 * Also handles demo data cleanup (--clean-demo).
 */

const UNRANKED_RANK = 9999;

// Demo IDs from seed_production.js
const DEMO_CITY_IDS = ["houston", "nyc", "la", "chicago"];
const DEMO_RESTAURANT_PREFIXES = ["hou-", "nyc-", "la-", "chi-"];

/**
 * Scans for existing demo data in prod.
 * @param {FirebaseFirestore} db
 * @returns {Promise<{demoCities: string[], demoRestaurants: string[], demoNotes: string[]}>}
 */
async function scanDemoData(db) {
  const demoCities = [];
  const demoRestaurants = [];
  const demoNotes = [];

  for (const id of DEMO_CITY_IDS) {
    const doc = await db.collection("cities").doc(id).get();
    if (doc.exists) demoCities.push(id);
  }

  // Query restaurants with demo-style IDs
  for (const prefix of DEMO_RESTAURANT_PREFIXES) {
    for (let i = 1; i <= 10; i++) {
      const id = `${prefix}${i}`;
      const doc = await db.collection("restaurants").doc(id).get();
      if (doc.exists) {
        demoRestaurants.push(id);
        // Check for insiderNotes subcollection
        const notesDoc = await db
          .collection("restaurants")
          .doc(id)
          .collection("insiderNotes")
          .doc("notes")
          .get();
        if (notesDoc.exists) demoNotes.push(id);
      }
    }
  }

  return { demoCities, demoRestaurants, demoNotes };
}

/**
 * Deletes demo data from prod.
 * @param {FirebaseFirestore} db
 * @param {{demoCities: string[], demoRestaurants: string[], demoNotes: string[]}} demoData
 * @param {boolean} confirm
 */
async function cleanDemoData(db, demoData, confirm) {
  const { demoCities, demoRestaurants, demoNotes } = demoData;
  const total = demoCities.length + demoRestaurants.length + demoNotes.length;

  if (total === 0) {
    console.log("No demo data found.");
    return;
  }

  console.log(`\nDemo data found:`);
  console.log(`  Cities:     ${demoCities.length} (${demoCities.join(", ")})`);
  console.log(`  Restaurants: ${demoRestaurants.length}`);
  console.log(`  Insider notes: ${demoNotes.length}`);

  if (!confirm) {
    console.log("\nDry run. Use --confirm to delete.\n");
    return;
  }

  // Delete insider notes first (subcollection)
  for (const id of demoNotes) {
    await db
      .collection("restaurants")
      .doc(id)
      .collection("insiderNotes")
      .doc("notes")
      .delete();
    console.log(`  DELETE insiderNotes: ${id}`);
  }

  // Delete restaurants
  for (const id of demoRestaurants) {
    await db.collection("restaurants").doc(id).delete();
    console.log(`  DELETE restaurant: ${id}`);
  }

  // Delete cities
  for (const id of demoCities) {
    await db.collection("cities").doc(id).delete();
    console.log(`  DELETE city: ${id}`);
  }

  console.log(`Deleted ${total} demo documents.\n`);
}

/**
 * Writes the Houston city doc and enriched restaurant docs.
 * @param {FirebaseFirestore} db
 * @param {Object} FieldValue - Firestore FieldValue
 * @param {Array} enrichedCandidates
 * @param {boolean} confirm
 * @returns {Promise<{created: number, updated: number, skipped: number}>}
 */
async function writeHoustonData(db, FieldValue, enrichedCandidates, confirm) {
  let created = 0;
  let updated = 0;
  let skipped = 0;

  const now = FieldValue.serverTimestamp();

  // Write city doc
  const cityRef = db.collection("cities").doc("houston");
  const cityDoc = await cityRef.get();
  if (!cityDoc.exists) {
    if (confirm) {
      await cityRef.set({
        id: "houston",
        name: "Houston",
        state: "TX",
        imageUrl:
          "https://images.unsplash.com/photo-1530089711124-9ca31fb9e863?w=800",
        description:
          "The most diverse food city in America. No debate.",
        restaurantCount: enrichedCandidates.length,
        createdAt: now,
        updatedAt: now,
      });
      console.log("  WRITE city: houston");
    }
    created++;
  } else {
    // Update restaurant count
    if (confirm) {
      await cityRef.update({
        restaurantCount: enrichedCandidates.length,
        updatedAt: now,
      });
      console.log("  UPDATE city: houston (restaurantCount)");
    }
    updated++;
  }

  // Write restaurant docs
  for (const candidate of enrichedCandidates) {
    const docId = `hou-${candidate.placeId}`;
    const ref = db.collection("restaurants").doc(docId);
    const doc = await ref.get();

    if (doc.exists) {
      // Update enrichment fields only, preserve user data
      if (confirm) {
        await ref.update({
          priceLevel: candidate.priceLevel,
          locations: [
            {
              name: candidate.area || "Houston",
              address: candidate.formattedAddress,
              latitude: candidate.latitude,
              longitude: candidate.longitude,
            },
          ],
          openingHours: candidate.openingHours,
          isMobileVenue: candidate.isMobileVenue,
          updatedAt: now,
        });
        console.log(`  UPDATE restaurant: ${docId} (${candidate.name})`);
      }
      updated++;
    } else {
      // Create new doc
      if (confirm) {
        await ref.set({
          id: docId,
          cityId: "houston",
          name: candidate.name,
          cuisine: candidate.cuisine,
          imageUrl: "placeholder://restaurant",
          description: "",
          rank: UNRANKED_RANK,
          voteCount: 0,
          priceLevel: candidate.priceLevel,
          placeId: candidate.placeId,
          isMobileVenue: candidate.isMobileVenue,
          openingHours: candidate.openingHours,
          displayOrder: candidate.displayOrder,
          locations: [
            {
              name: candidate.area || "Houston",
              address: candidate.formattedAddress,
              latitude: candidate.latitude,
              longitude: candidate.longitude,
            },
          ],
          vibeTags: [],
          createdAt: now,
          updatedAt: now,
        });
        console.log(`  CREATE restaurant: ${docId} (${candidate.name})`);
      }
      created++;
    }
  }

  return { created, updated, skipped };
}

module.exports = {
  scanDemoData,
  cleanDemoData,
  writeHoustonData,
  UNRANKED_RANK,
  DEMO_CITY_IDS,
  DEMO_RESTAURANT_PREFIXES,
};
