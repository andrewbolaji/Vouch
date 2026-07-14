#!/usr/bin/env node

/**
 * One-off script: seed the 7 new Houston restaurants that do not yet
 * exist in Firestore. Run BEFORE set_houston_launch_order.js.
 *
 * Usage:
 *   node scripts/seed_houston_new.js              # dry run
 *   node scripts/seed_houston_new.js --confirm    # live write
 *
 * Requires Application Default Credentials for Firestore admin access.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const { Timestamp } = admin.firestore;

const NEW_RESTAURANTS = [
  {
    id: "hou-11",
    cityId: "houston",
    name: "Tacos Los Brothers",
    cuisine: "Mexican (Tacos)",
    imageUrl: "placeholder://restaurant",
    description: "Dollar tacos from a gas-station truck that"
      + " somehow became the best late-night move in Houston."
      + " Carne asada, al pastor, fresh tortillas.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 1,
    displayOrder: 9999,
    locations: [{ name: "South Main", address: "9365 S Main St, Houston, TX 77025", latitude: 0, longitude: 0 }],
    vibeTags: ["Late Night", "Cash Friendly", "No Frills"],
    isMobileVenue: true,
  },
  {
    id: "hou-12",
    cityId: "houston",
    name: "Crave Suya",
    cuisine: "West African",
    imageUrl: "placeholder://restaurant",
    description: "Nigerian suya done right, from a food truck"
      + " that draws lines across Houston. Spicy grilled beef"
      + " skewers with yaji seasoning.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 1,
    displayOrder: 9999,
    locations: [{ name: "Richmond Ave", address: "8633 Richmond Ave, Houston, TX 77063", latitude: 0, longitude: 0 }],
    vibeTags: ["Flavor Bomb", "Hidden Gem", "Cash Friendly"],
    isMobileVenue: true,
  },
  {
    id: "hou-13",
    cityId: "houston",
    name: "The Peri Peri Factory",
    cuisine: "Portuguese-African (Peri Peri Chicken)",
    imageUrl: "placeholder://restaurant",
    description: "Flame-grilled peri peri chicken with sauces"
      + " from mild to extra hot. Houston's first."
      + " Halal-certified.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 2,
    displayOrder: 9999,
    locations: [{ name: "Westheimer", address: "6375 Westheimer Rd, Houston, TX 77057", latitude: 0, longitude: 0 }],
    vibeTags: ["Spicy", "Halal", "Casual"],
  },
  {
    id: "hou-14",
    cityId: "houston",
    name: "Top Sushi",
    cuisine: "Japanese (Sushi)",
    imageUrl: "placeholder://restaurant",
    description: "Creative sushi rolls and fresh-cut fish on"
      + " Westheimer. Known for signature rolls with bold"
      + " flavor combos.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 2,
    displayOrder: 9999,
    locations: [{ name: "Westheimer", address: "8401 Westheimer Rd, Ste 160, Houston, TX 77063", latitude: 0, longitude: 0 }],
    vibeTags: ["Date Night", "Group Friendly", "Good Drinks"],
  },
  {
    id: "hou-15",
    cityId: "houston",
    name: "The Better Box",
    cuisine: "Comfort Food (Food Truck)",
    imageUrl: "placeholder://restaurant",
    description: "A food truck turning out loaded comfort-food"
      + " boxes that punch above their price point.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 1,
    displayOrder: 9999,
    locations: [{ name: "Cypress Creek", address: "6560 Cypress Creek Pkwy, Houston, TX 77069", latitude: 0, longitude: 0 }],
    vibeTags: ["Comfort Food", "Cash Friendly", "Hidden Gem"],
    isMobileVenue: true,
  },
  {
    id: "hou-16",
    cityId: "houston",
    name: "Joey Uptown",
    cuisine: "Globally-Inspired New American",
    imageUrl: "placeholder://restaurant",
    description: "A 10,000-square-foot Galleria restaurant with"
      + " fire-torched sushi, steaks, and a temperature-controlled"
      + " patio. Part of the JOEY chain.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 3,
    displayOrder: 9999,
    locations: [{ name: "Galleria / Uptown", address: "5045 Westheimer Rd, Ste X01, Houston, TX 77056", latitude: 0, longitude: 0 }],
    vibeTags: ["Date Night", "Group Friendly", "Trendy"],
  },
  {
    id: "hou-17",
    cityId: "houston",
    name: "Lotus Seafood",
    cuisine: "Cajun Seafood",
    imageUrl: "placeholder://restaurant",
    description: "Houston-born Cajun seafood by the pound since"
      + " 2006. Five locations. Famous for the Crack Sauce.",
    rank: 9999,
    voteCount: 0,
    priceLevel: 2,
    displayOrder: 9999,
    locations: [{ name: "Southwest Freeway", address: "9531 SW Fwy, Houston, TX 77074", latitude: 0, longitude: 0 }],
    vibeTags: ["Flavor Bomb", "Group Friendly", "Casual"],
  },
];

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nSeed new Houston restaurants`);
  console.log(`Target project: ${projectId}`);
  console.log(`Mode: ${confirm ? "LIVE WRITE" : "DRY RUN"}\n`);

  const now = Timestamp.now();

  for (const r of NEW_RESTAURANTS) {
    const ref = db.collection("restaurants").doc(r.id);
    const existing = await ref.get();

    if (existing.exists) {
      console.log(`  SKIP ${r.name} (${r.id}) -- already exists`);
      continue;
    }

    console.log(`  WRITE ${r.name} (${r.id})`);
    if (confirm) {
      await ref.set({ ...r, createdAt: now, updatedAt: now });
    }
  }

  if (confirm) {
    console.log("\nDone.\n");
  } else {
    console.log("\nDry run -- no writes. Use --confirm to apply.\n");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Script failed:", err);
  process.exit(1);
});
