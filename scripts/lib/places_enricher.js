/**
 * Google Places enrichment module.
 *
 * Resolves each candidate row to a canonical Place ID with priceLevel,
 * lat/lng, formatted address, and opening hours.
 *
 * Match-confidence logic:
 * - Name similarity: token overlap >= 0.5
 * - City match: returned address must fall within the Houston metro
 *   (Houston, Spring, Katy, Pearland, Tomball, Missouri City, Sugar Land,
 *   Cypress, Humble, Pasadena, Bellaire, The Woodlands, etc.) OR the
 *   returned lat/lng must fall inside the Houston metro bounding box.
 * - Address-less rows: always manual review regardless of match quality.
 */

const CALL_CAP = 120;

// Houston metro bounding box (generous)
const HOUSTON_METRO_BBOX = {
  north: 30.20,
  south: 29.40,
  east: -94.90,
  west: -96.00,
};

// Houston metro city names (lowercase)
const HOUSTON_METRO_CITIES = new Set([
  "houston", "spring", "katy", "pearland", "tomball",
  "missouri city", "sugar land", "cypress", "humble",
  "pasadena", "bellaire", "the woodlands", "league city",
  "friendswood", "richmond", "rosenberg", "stafford",
  "webster", "baytown", "la porte", "deer park",
  "galena park", "south houston", "west university place",
  "jersey village", "hedwig village", "piney point village",
  "bunker hill village", "hunters creek village",
]);

// Google Places priceLevel enum to Vouch numeric mapping
const PRICE_LEVEL_MAP = {
  PRICE_LEVEL_FREE: 1,
  PRICE_LEVEL_INEXPENSIVE: 1,
  PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3,
  PRICE_LEVEL_VERY_EXPENSIVE: 4,
};

/**
 * Enriches candidates with Google Places data.
 * @param {Array} candidates - Parsed CSV candidates.
 * @param {string} apiKey - Google Places API key.
 * @param {Function} [fetchFn] - Fetch function (injectable for testing).
 * @returns {Promise<{enriched: Array, manualReview: Array, callCount: number}>}
 */
async function enrichCandidates(candidates, apiKey, fetchFn) {
  const _fetch = fetchFn || globalThis.fetch;
  const enriched = [];
  const manualReview = [];
  let callCount = 0;

  for (const candidate of candidates) {
    if (callCount >= CALL_CAP) {
      console.error(
        `ABORT: Places API call cap (${CALL_CAP}) reached at candidate ` +
        `"${candidate.name}". Remaining candidates go to manual review.`
      );
      manualReview.push({
        ...candidate,
        reason: "call cap reached",
      });
      continue;
    }

    // Address-less rows always go to manual review
    if (!candidate.address) {
      manualReview.push({
        ...candidate,
        reason: "no input address, verify manually",
      });
      continue;
    }

    const query = `"${candidate.name}" "${candidate.address}"`;
    callCount++;
    console.log(`[${callCount}/${candidates.length}] Places lookup: ${candidate.name}`);

    try {
      const result = await callPlacesApi(query, apiKey, _fetch);
      if (!result || result.places.length === 0) {
        manualReview.push({ ...candidate, reason: "no Places result" });
        continue;
      }

      const top = result.places[0];
      const nameScore = tokenOverlap(candidate.name, top.displayName?.text || "");
      const cityMatch = checkCityMatch(top);

      if (nameScore < 0.5) {
        manualReview.push({
          ...candidate,
          reason: `name mismatch (score=${nameScore.toFixed(2)}, got "${top.displayName?.text}")`,
        });
        continue;
      }

      if (!cityMatch) {
        manualReview.push({
          ...candidate,
          reason: `city mismatch (got "${top.formattedAddress}")`,
        });
        continue;
      }

      enriched.push({
        ...candidate,
        placeId: top.id,
        priceLevel: mapPriceLevel(top.priceLevel),
        latitude: top.location?.latitude || 0,
        longitude: top.location?.longitude || 0,
        formattedAddress: top.formattedAddress || candidate.address,
        openingHours: top.currentOpeningHours?.weekdayDescriptions || [],
      });
    } catch (err) {
      manualReview.push({
        ...candidate,
        reason: `API error: ${err.message}`,
      });
    }
  }

  return { enriched, manualReview, callCount };
}

async function callPlacesApi(query, apiKey, _fetch) {
  const url = "https://places.googleapis.com/v1/places:searchText";
  const response = await _fetch(url, {
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

/**
 * Token overlap score between two restaurant names.
 * Returns 0-1 where 1 = all tokens in the candidate appear in the result.
 */
function tokenOverlap(candidateName, resultName) {
  const normalize = (s) =>
    s.toLowerCase().replace(/[^a-z0-9\s]/g, "").split(/\s+/).filter(Boolean);

  const candidateTokens = normalize(candidateName);
  const resultTokens = new Set(normalize(resultName));

  if (candidateTokens.length === 0) return 0;

  const matches = candidateTokens.filter((t) => resultTokens.has(t)).length;
  return matches / candidateTokens.length;
}

/**
 * Checks if a Places result is within the Houston metro area.
 * Uses both city name matching and bounding box.
 */
function checkCityMatch(place) {
  // Check address text for metro city names
  const addr = (place.formattedAddress || "").toLowerCase();
  for (const city of HOUSTON_METRO_CITIES) {
    if (addr.includes(city)) return true;
  }
  // Check TX in address (broad, but filters out other states)
  if (addr.includes(", tx ") || addr.endsWith(", tx")) {
    // Also check bounding box
    const lat = place.location?.latitude;
    const lng = place.location?.longitude;
    if (lat && lng) {
      return (
        lat >= HOUSTON_METRO_BBOX.south &&
        lat <= HOUSTON_METRO_BBOX.north &&
        lng >= HOUSTON_METRO_BBOX.west &&
        lng <= HOUSTON_METRO_BBOX.east
      );
    }
  }
  return false;
}

function mapPriceLevel(level) {
  if (!level) return 2; // safe default
  return PRICE_LEVEL_MAP[level] || 2;
}

module.exports = {
  enrichCandidates,
  tokenOverlap,
  checkCityMatch,
  mapPriceLevel,
  CALL_CAP,
  HOUSTON_METRO_CITIES,
  HOUSTON_METRO_BBOX,
  PRICE_LEVEL_MAP,
};
