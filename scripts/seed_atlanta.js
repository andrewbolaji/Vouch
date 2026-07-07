#!/usr/bin/env node

/**
 * Atlanta seed pipeline: enrich 17 curated candidates via Google Places
 * and seed to production Firestore.
 *
 * Mirrors seed_houston.js but is self-contained for Atlanta only.
 * Touches ONLY the "atlanta" city doc, "atl-" restaurant docs, and their
 * insiderNotes subcollections. Does not read, write, or delete any
 * Houston, NYC, LA, or Chicago data.
 *
 * Usage:
 *   # Dry run (default): shows what would be created/updated
 *   node scripts/seed_atlanta.js
 *
 *   # Write enriched Atlanta data to prod
 *   node scripts/seed_atlanta.js --confirm
 *
 * Requires:
 *   - GOOGLE_PLACES_API_KEY env var (for Places enrichment)
 *   - Application Default Credentials for Firestore admin access
 *     (gcloud auth application-default login, or GOOGLE_APPLICATION_CREDENTIALS)
 *   - data/atlanta_candidates_seedready.csv in the project root
 *
 * NEVER call this from client code. One-time admin operation.
 */

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

// Initialize Firebase Admin with default credentials
admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

// ---- Atlanta metro bounding box and city names ----

const ATLANTA_METRO_BBOX = {
  north: 34.10,
  south: 33.45,
  east: -83.90,
  west: -84.75,
};

const ATLANTA_METRO_CITIES = new Set([
  "atlanta", "decatur", "stone mountain", "mableton",
  "fairburn", "sandy springs", "buckhead", "midtown",
  "east atlanta", "old fourth ward", "west midtown",
  "roswell", "marietta", "smyrna", "kennesaw",
  "alpharetta", "duluth", "lawrenceville", "norcross",
  "college park", "east point", "hapeville", "avondale estates",
  "tucker", "clarkston", "lithonia", "conyers",
  "peachtree city", "fayetteville", "jonesboro",
  "union city", "palmetto", "tyrone",
]);

// Google Places priceLevel enum to Vouch numeric mapping
const PRICE_LEVEL_MAP = {
  PRICE_LEVEL_FREE: 1,
  PRICE_LEVEL_INEXPENSIVE: 1,
  PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3,
  PRICE_LEVEL_VERY_EXPENSIVE: 4,
};

// ---- CSV Parser (inline, mirrors csv_parser.js) ----

function parseCsvLine(line) {
  const fields = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (ch === "," && !inQuotes) {
      fields.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  fields.push(current);
  return fields;
}

function parseCsv(csvPath) {
  const content = fs.readFileSync(csvPath, "utf-8");
  const lines = content.split("\n").filter((l) => l.trim().length > 0);

  if (lines.length < 2) {
    throw new Error("CSV has no data rows");
  }

  const dataLines = lines.slice(1);
  const candidates = [];

  for (let i = 0; i < dataLines.length; i++) {
    const fields = parseCsvLine(dataLines[i]);
    if (fields.length < 5) continue;

    candidates.push({
      name: (fields[0] || "").trim(),
      cuisine: (fields[1] || "").trim(),
      area: (fields[2] || "").trim(),
      address: (fields[3] || "").trim(),
      rank: parseInt((fields[4] || "0").trim(), 10),
      whatToOrder: (fields[5] || "").trim(),
      priceFallback: parseInt((fields[6] || "2").trim(), 10),
      displayOrder: i + 1,
    });
  }

  return candidates;
}

// ---- Places enrichment (mirrors places_enricher.js for Atlanta) ----

function tokenOverlap(candidateName, resultName) {
  const normalize = (s) =>
    s.toLowerCase().replace(/[^a-z0-9\s]/g, "").split(/\s+/).filter(Boolean);

  const candidateTokens = normalize(candidateName);
  const resultTokens = new Set(normalize(resultName));

  if (candidateTokens.length === 0) return 0;

  const matches = candidateTokens.filter((t) => resultTokens.has(t)).length;
  return matches / candidateTokens.length;
}

function checkAtlantaCityMatch(place) {
  const addr = (place.formattedAddress || "").toLowerCase();
  for (const city of ATLANTA_METRO_CITIES) {
    if (addr.includes(city)) return true;
  }
  if (addr.includes(", ga ") || addr.endsWith(", ga")) {
    const lat = place.location?.latitude;
    const lng = place.location?.longitude;
    if (lat && lng) {
      return (
        lat >= ATLANTA_METRO_BBOX.south &&
        lat <= ATLANTA_METRO_BBOX.north &&
        lng >= ATLANTA_METRO_BBOX.west &&
        lng <= ATLANTA_METRO_BBOX.east
      );
    }
  }
  return false;
}

function mapPriceLevel(level) {
  if (!level) return null; // return null so we can fall back to CSV value
  return PRICE_LEVEL_MAP[level] || null;
}

async function callPlacesApi(query, apiKey) {
  const url = "https://places.googleapis.com/v1/places:searchText";
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": [
        "places.id",
        "places.displayName",
        "places.formattedAddress",
        "places.location",
        "places.priceLevel",
        "places.currentOpeningHours",
      ].join(","),
    },
    body: JSON.stringify({
      textQuery: query,
      maxResultCount: 3,
    }),
  });

  if (!response.ok) {
    throw new Error(`Places API returned ${response.status}`);
  }

  return response.json();
}

async function enrichCandidates(candidates, apiKey) {
  const enriched = [];
  const manualReview = [];
  let callCount = 0;

  for (const candidate of candidates) {
    if (!candidate.address) {
      manualReview.push({
        ...candidate,
        reason: "no input address, verify manually",
        placesName: null,
        placesAddress: null,
      });
      continue;
    }

    // Use name + address for disambiguation
    const query = `"${candidate.name}" "${candidate.address}"`;
    callCount++;
    console.log(
      `[${callCount}/${candidates.length}] Places lookup: ${candidate.name}`
    );

    try {
      const result = await callPlacesApi(query, apiKey);
      if (!result || !result.places || result.places.length === 0) {
        manualReview.push({
          ...candidate,
          reason: "no Places result",
          placesName: null,
          placesAddress: null,
        });
        continue;
      }

      const top = result.places[0];
      const placesName = top.displayName?.text || "";
      const placesAddress = top.formattedAddress || "";
      const nameScore = tokenOverlap(candidate.name, placesName);
      const cityMatch = checkAtlantaCityMatch(top);

      if (nameScore < 0.5) {
        manualReview.push({
          ...candidate,
          reason: `name mismatch (score=${nameScore.toFixed(2)}, got "${placesName}")`,
          placesName,
          placesAddress,
        });
        continue;
      }

      if (!cityMatch) {
        manualReview.push({
          ...candidate,
          reason: `city mismatch (got "${placesAddress}")`,
          placesName,
          placesAddress,
        });
        continue;
      }

      const googlePrice = mapPriceLevel(top.priceLevel);

      enriched.push({
        ...candidate,
        placeId: top.id,
        priceLevel: googlePrice !== null ? googlePrice : candidate.priceFallback,
        priceLevelSource: googlePrice !== null ? "google" : "fallback",
        latitude: top.location?.latitude || 0,
        longitude: top.location?.longitude || 0,
        formattedAddress: placesAddress || candidate.address,
        openingHours: top.currentOpeningHours?.weekdayDescriptions || [],
        placesName,
        placesAddress,
      });
    } catch (err) {
      manualReview.push({
        ...candidate,
        reason: `API error: ${err.message}`,
        placesName: null,
        placesAddress: null,
      });
    }
  }

  return { enriched, manualReview, callCount };
}

// ---- Firestore writer (Atlanta only) ----

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

async function writeAtlantaData(db, FieldValue, enrichedCandidates, confirm) {
  let created = 0;
  let updated = 0;
  let skipped = 0;

  const now = FieldValue.serverTimestamp();

  // Write city doc
  const cityRef = db.collection("cities").doc("atlanta");
  const cityDoc = await cityRef.get();
  if (!cityDoc.exists) {
    if (confirm) {
      await cityRef.set({
        id: "atlanta",
        name: "Atlanta",
        state: "GA",
        imageUrl:
          "https://images.unsplash.com/photo-1575917649111-0cee4e0e4b5b?w=800",
        description:
          "Where soul food meets global flavor. The South starts here.",
        restaurantCount: enrichedCandidates.length,
        status: "live",
        createdAt: now,
        updatedAt: now,
      });
      console.log("  WRITE city: atlanta");
    } else {
      console.log("  [DRY] WRITE city: atlanta");
    }
    created++;
  } else {
    if (confirm) {
      await cityRef.update({
        restaurantCount: enrichedCandidates.length,
        updatedAt: now,
      });
      console.log("  UPDATE city: atlanta (restaurantCount)");
    } else {
      console.log("  [DRY] UPDATE city: atlanta (restaurantCount)");
    }
    updated++;
  }

  // Write restaurant docs and insiderNotes
  for (const candidate of enrichedCandidates) {
    const docId = candidate.placeId
      ? `atl-${candidate.placeId}`
      : `atl-${slugify(candidate.name)}`;

    if (!candidate.placeId) {
      console.log(
        `  WARNING: no placeId for "${candidate.name}", using slug ID: ${docId}`
      );
    }

    const ref = db.collection("restaurants").doc(docId);
    const doc = await ref.get();

    if (doc.exists) {
      // Update enrichment fields only, preserve user data
      if (confirm) {
        await ref.update({
          priceLevel: candidate.priceLevel,
          locations: [
            {
              name: candidate.area || "Atlanta",
              address: candidate.formattedAddress,
              latitude: candidate.latitude,
              longitude: candidate.longitude,
            },
          ],
          openingHours: candidate.openingHours || [],
          updatedAt: now,
        });
        console.log(`  UPDATE restaurant: ${docId} (${candidate.name})`);
      } else {
        console.log(`  [DRY] UPDATE restaurant: ${docId} (${candidate.name})`);
      }
      updated++;
    } else {
      if (confirm) {
        await ref.set({
          id: docId,
          cityId: "atlanta",
          name: candidate.name,
          cuisine: candidate.cuisine,
          imageUrl: "placeholder://restaurant",
          description: "",
          rank: candidate.rank,
          voteCount: 0,
          commentCount: 0,
          priceLevel: candidate.priceLevel,
          placeId: candidate.placeId || null,
          isMobileVenue: false,
          openingHours: candidate.openingHours || [],
          displayOrder: candidate.displayOrder,
          rankScore: 0,
          locations: [
            {
              name: candidate.area || "Atlanta",
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
      } else {
        console.log(`  [DRY] CREATE restaurant: ${docId} (${candidate.name})`);
      }
      created++;
    }

    // Write insiderNotes subcollection
    const notesRef = ref.collection("insiderNotes").doc("notes");
    const notesDoc = await (doc.exists ? notesRef.get() : Promise.resolve({ exists: false }));

    if (!notesDoc.exists) {
      if (confirm) {
        await notesRef.set({
          restaurantId: docId,
          whatToOrder: candidate.whatToOrder || "",
          insiderTip: "",
        });
        console.log(`  CREATE insiderNotes: ${docId}`);
      } else {
        console.log(`  [DRY] CREATE insiderNotes: ${docId}`);
      }
    } else {
      console.log(`  SKIP insiderNotes: ${docId} (already exists)`);
    }
  }

  return { created, updated, skipped };
}

// ---- Main ----

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nAtlanta seed pipeline`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  // 1. Parse CSV
  const csvPath = path.resolve(
    __dirname,
    "../data/atlanta_candidates_seedready.csv"
  );
  console.log(`Parsing CSV: ${csvPath}`);
  let candidates;
  try {
    candidates = parseCsv(csvPath);
  } catch (err) {
    console.error(`CSV parse error: ${err.message}`);
    process.exit(1);
  }
  console.log(`Parsed ${candidates.length} candidates.\n`);

  // 2. Enrich via Google Places
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

  // Print match table
  console.log("=== PLACES MATCH TABLE ===");
  console.log(
    "Rank | Our Name                  | Places Name               | " +
    "Places Address                                      | Price (src)  | Match"
  );
  console.log("-".repeat(160));
  for (const e of enriched) {
    const priceStr = `${e.priceLevel} (${e.priceLevelSource})`;
    console.log(
      `${String(e.rank).padStart(4)} | ` +
      `${e.name.padEnd(25)} | ` +
      `${(e.placesName || "").padEnd(25)} | ` +
      `${(e.placesAddress || "").padEnd(50)} | ` +
      `${priceStr.padEnd(12)} | OK`
    );
  }
  console.log("");

  if (manualReview.length > 0) {
    console.log("=== MANUAL REVIEW LIST ===");
    for (const r of manualReview) {
      console.log(`  ${r.name} | ${r.reason}`);
      if (r.placesName) {
        console.log(`    Places returned: "${r.placesName}" at "${r.placesAddress}"`);
      }
    }
    console.log("");
  }

  // 3. Write to Firestore
  if (enriched.length === 0) {
    console.log("No enriched candidates to write. Check manual review list.");
    process.exit(1);
  }

  console.log("Writing to Firestore...");
  const { created, updated, skipped } = await writeAtlantaData(
    db,
    FieldValue,
    enriched,
    confirm
  );

  console.log(`\nSummary:`);
  console.log(`  Created: ${created}`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped: ${skipped}`);
  console.log(`  Total docs: ${created + updated + skipped}`);

  if (!confirm) {
    console.log(
      "\nThis was a dry run. To write to production:\n" +
      "  node scripts/seed_atlanta.js --confirm\n"
    );
  } else {
    console.log("\nDone. Atlanta data seeded.");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Seed script failed:", err);
  process.exit(1);
});
