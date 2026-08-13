/**
 * Publishing a city, with the preconditions that make a class of bug
 * impossible rather than fixing one instance of it.
 *
 * Why this exists. Setting a city live is one field, `status`, and it
 * is the difference between a shipped app and a usable one. Both seed
 * writers were narrowed to create-only by commit bba62e0, correctly,
 * so publishing had become an undocumented manual edit in the
 * Firestore console with zero coverage. That is not something to
 * leave to somebody remembering.
 *
 * Why the preconditions are the point. Every blocking check below
 * corresponds to a defect actually found in production during the
 * August 2026 remediation, not to a hypothetical:
 *
 *   displayOrder    Chicago, LA and NYC carried it on 0 of 10
 *                   documents each. assignRanks sorts an absent
 *                   displayOrder last, so a recompute on a city in
 *                   that state discards the curated order it was
 *                   published with.
 *   rank integrity  rank is what the entire UI keys on, including the
 *                   free tier filter in restaurant_repository.dart.
 *                   A duplicate or a gap silently drops or doubles a
 *                   row.
 *   free tier size  A city with fewer than kFreeTierMaxRank
 *                   restaurants publishes a paywall promising ranks
 *                   the city does not have. That is finding 11 from
 *                   the other direction.
 *   restaurantCount A known drifting denormalization with no sync
 *                   mechanism, and it is displayed.
 *
 * Warnings are reported and do not block, because they are product
 * judgements rather than integrity failures. A city can legitimately
 * launch with missing photographs if somebody decides that.
 *
 * Pure. Takes a db, touches one named city, returns a result rather
 * than printing or exiting, so it is testable without a project.
 */

/** Rank at or below which a free user may read. Mirrors kFreeTierMaxRank. */
const FREE_TIER_MAX_RANK = 5;

/** The value that makes a city browsable. Mirrors CityStatus.live. */
const STATUS_LIVE = "live";

/**
 * Checks whether a city is safe to publish, without writing anything.
 *
 * @param {object} db Firestore instance.
 * @param {string} cityId The one city to check.
 * @returns {Promise<object>} { ok, alreadyLive, blockers, warnings, stats }
 */
async function checkCity(db, cityId) {
  const blockers = [];
  const warnings = [];

  const cityDoc = await db.collection("cities").doc(cityId).get();
  if (!cityDoc.exists) {
    return {
      ok: false,
      alreadyLive: false,
      blockers: [`City "${cityId}" does not exist.`],
      warnings,
      stats: null,
    };
  }

  const city = cityDoc.data();
  const alreadyLive = city.status === STATUS_LIVE;

  const snap = await db
    .collection("restaurants")
    .where("cityId", "==", cityId)
    .get();
  const restaurants = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // --- Blocking: enough restaurants for the tier the app promises ---
  if (restaurants.length < FREE_TIER_MAX_RANK) {
    blockers.push(
      `Only ${restaurants.length} restaurants, need at least ` +
      `${FREE_TIER_MAX_RANK} for the free tier.`
    );
  }

  // --- Blocking: displayOrder present on every document ---
  const missingDisplayOrder = restaurants.filter(
    (r) => typeof r.displayOrder !== "number"
  );
  if (missingDisplayOrder.length > 0) {
    blockers.push(
      `${missingDisplayOrder.length} of ${restaurants.length} restaurants ` +
      "have no displayOrder, so a rank recompute would discard the curated " +
      "order: " +
      missingDisplayOrder.map((r) => `${r.name} (${r.id})`).join(", ")
    );
  }

  // --- Blocking: rank integrity ---
  const badRank = restaurants.filter((r) => typeof r.rank !== "number");
  if (badRank.length > 0) {
    blockers.push(
      `${badRank.length} restaurants have no usable rank: ` +
      badRank.map((r) => `${r.name} (${r.id})`).join(", ")
    );
  } else {
    const ranks = restaurants.map((r) => r.rank).sort((a, b) => a - b);
    const seen = new Set();
    const dupes = new Set();
    for (const r of ranks) {
      if (seen.has(r)) dupes.add(r);
      seen.add(r);
    }
    if (dupes.size > 0) {
      blockers.push(`Duplicate ranks: ${[...dupes].sort((a, b) => a - b)
        .join(", ")}`);
    }
    // Contiguous from 1. A gap means a row silently vanishes from a
    // list the user is told is a Top N.
    const gaps = [];
    for (let i = 1; i <= ranks.length; i++) {
      if (!seen.has(i)) gaps.push(i);
    }
    if (gaps.length > 0) {
      blockers.push(
        `Ranks are not contiguous from 1. Missing: ${gaps.join(", ")}`
      );
    }
  }

  // --- Blocking: restaurantCount agrees with reality ---
  if (city.restaurantCount !== restaurants.length) {
    blockers.push(
      `cities/${cityId}.restaurantCount is ${city.restaurantCount} but ` +
      `${restaurants.length} restaurants exist. It is displayed, and it ` +
      "has no sync mechanism, so it has to be corrected deliberately."
    );
  }

  // --- Warnings: product judgements, not integrity ---
  const noImage = restaurants.filter(
    (r) => !r.imageUrl || String(r.imageUrl).startsWith("placeholder://")
  );
  if (noImage.length > 0) {
    warnings.push(
      `${noImage.length} of ${restaurants.length} restaurants have no ` +
      "usable image and will render a grey placeholder."
    );
  }

  const zeroCoords = restaurants.filter((r) =>
    (r.locations || []).some((l) => !l.latitude && !l.longitude)
  );
  if (zeroCoords.length > 0) {
    warnings.push(
      `${zeroCoords.length} restaurants have a location at 0,0, which is ` +
      "a point in the Gulf of Guinea. Any map or distance feature will " +
      "place them there."
    );
  }

  let withNotes = 0;
  for (const r of restaurants) {
    const notes = await db
      .collection("restaurants")
      .doc(r.id)
      .collection("insiderNotes")
      .doc("notes")
      .get();
    if (notes.exists) withNotes++;
  }
  if (withNotes < restaurants.length) {
    warnings.push(
      `${restaurants.length - withNotes} of ${restaurants.length} ` +
      "restaurants have no insider notes. City Insider subscribers see " +
      "the empty state on those."
    );
  }

  return {
    ok: blockers.length === 0,
    alreadyLive,
    blockers,
    warnings,
    stats: {
      name: city.name,
      currentStatus: city.status || "(absent, parses as comingSoon)",
      restaurants: restaurants.length,
      withNotes,
      withoutImage: noImage.length,
    },
  };
}

/**
 * Publishes one named city, if it passes.
 *
 * Idempotent: a city already live is left alone and reported as a
 * no-op rather than rewritten, so re-running is always safe.
 *
 * @param {object} db Firestore instance.
 * @param {string} cityId The one city to publish.
 * @param {object} [options] { confirm } false performs no write.
 * @returns {Promise<object>} { published, reason, check }
 */
async function publishCity(db, cityId, options = {}) {
  const { confirm = false } = options;
  const check = await checkCity(db, cityId);

  if (!check.ok) {
    return { published: false, reason: "blocked", check };
  }
  if (check.alreadyLive) {
    return { published: false, reason: "already-live", check };
  }
  if (!confirm) {
    return { published: false, reason: "dry-run", check };
  }

  // Only `status`. Publishing is one field, and widening it here
  // would make this script a second writer competing with the seed
  // scripts that were deliberately narrowed to create-only.
  await db.collection("cities").doc(cityId).update({ status: STATUS_LIVE });

  // Read back rather than trusting the write.
  const after = await db.collection("cities").doc(cityId).get();
  if (!after.exists || after.data().status !== STATUS_LIVE) {
    return { published: false, reason: "verify-failed", check };
  }

  return { published: true, reason: "published", check };
}

module.exports = {
  checkCity,
  publishCity,
  FREE_TIER_MAX_RANK,
  STATUS_LIVE,
};
