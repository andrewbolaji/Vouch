/**
 * CSV parser for houston_candidates_seedready.csv.
 *
 * Columns: Restaurant, Cuisine, Area / City, Address, Source, Place ID
 * - "Source" is curation-only and dropped at write time.
 * - "(FOOD TRUCK)" in Cuisine sets isMobileVenue and is stripped from cuisine.
 */

const fs = require("fs");
const path = require("path");

const FOOD_TRUCK_PATTERN = /\(FOOD\s*TRUCK\)/i;

/**
 * Parses the CSV file and returns an array of candidate objects.
 * @param {string} csvPath - Absolute path to the CSV file.
 * @returns {Array<Object>} Parsed candidates.
 */
function parseCsv(csvPath) {
  const content = fs.readFileSync(csvPath, "utf-8");
  const lines = content.split("\n").filter((l) => l.trim().length > 0);

  if (lines.length < 2) {
    throw new Error("CSV has no data rows");
  }

  // Skip header row
  const dataLines = lines.slice(1);
  const candidates = [];

  for (let i = 0; i < dataLines.length; i++) {
    const fields = parseCsvLine(dataLines[i]);
    if (fields.length < 4) continue; // Skip malformed rows

    const rawCuisine = (fields[1] || "").trim();
    const isMobileVenue = FOOD_TRUCK_PATTERN.test(rawCuisine);
    const cuisine = rawCuisine.replace(FOOD_TRUCK_PATTERN, "").trim();

    candidates.push({
      name: (fields[0] || "").trim(),
      cuisine,
      area: (fields[2] || "").trim(),
      address: (fields[3] || "").trim(),
      isMobileVenue,
      // Source (fields[4]) deliberately dropped
      placeId: (fields[5] || "").trim() || null,
      displayOrder: i + 1, // 1-based from CSV row order
    });
  }

  return candidates;
}

/**
 * Simple CSV line parser that handles quoted fields with commas.
 */
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

module.exports = { parseCsv, parseCsvLine, FOOD_TRUCK_PATTERN };
