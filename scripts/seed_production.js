#!/usr/bin/env node

/**
 * Vouch seed script: writes seed data to Firestore.
 *
 * Usage:
 *   node scripts/seed_production.js              # dry run
 *   node scripts/seed_production.js --confirm    # write new docs only
 *   node scripts/seed_production.js --force --confirm  # overwrite all docs
 *
 * Requires:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account key
 *   - OR run after `firebase login` with project access
 *
 * Idempotent: skips docs that already have a createdAt field.
 * --force: overwrites every doc regardless of createdAt. Preserves original
 *   createdAt when the doc already has one, always sets updatedAt to now.
 *   PRE-LAUNCH TOOL ONLY: once real users exist, --force would overwrite
 *   live voteCount and rank data.
 *
 * Prints write-count vs skip-count before the --confirm prompt.
 *
 * NEVER call this from client code. One-time admin operation.
 */

const admin = require("firebase-admin");

// Initialize with default credentials (service account or gcloud auth)
admin.initializeApp();
const db = admin.firestore();

const { Timestamp, FieldValue } = admin.firestore;

// ---- Seed Data ----

const cities = [
  { id: "houston", name: "Houston", state: "TX", imageUrl: "https://images.unsplash.com/photo-1530089711124-9ca31fb9e863?w=800", description: "The most diverse food city in America. No debate.", restaurantCount: 10, status: "live" },
  { id: "nyc", name: "New York", state: "NY", imageUrl: "https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800", description: "Only the best survive here.", restaurantCount: 10, status: "comingSoon" },
  { id: "la", name: "Los Angeles", state: "CA", imageUrl: "https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=800", description: "Tacos, sushi, and everything between. Always outside.", restaurantCount: 10, status: "comingSoon" },
  { id: "chicago", name: "Chicago", state: "IL", imageUrl: "https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=800", description: "Deep dish is just the beginning.", restaurantCount: 10, status: "comingSoon" },
];

const restaurants = [
  // Houston
  { id: "hou-1", cityId: "houston", name: "Mensho", cuisine: "Ramen", imageUrl: "placeholder://restaurant", description: "Tokyo ramen master Tomoharu Shono's Houston shop. Michelin-recognized, known for a wagyu-meets-Texas-BBQ bowl.", rank: 1, voteCount: 0, priceLevel: 2, locations: [{ name: "Chinatown", address: "9889 Bellaire Blvd, Ste C308, Houston, TX 77036", latitude: 0, longitude: 0 }], vibeTags: ["Quick Bite", "Cozy", "Neighborhood Favorite"] },
  { id: "hou-11", cityId: "houston", name: "Tacos Los Brothers", cuisine: "Mexican (Tacos)", imageUrl: "placeholder://restaurant", description: "Dollar tacos from a gas-station truck that somehow became the best late-night move in Houston. Carne asada, al pastor, fresh tortillas.", rank: 2, voteCount: 0, priceLevel: 1, locations: [{ name: "South Main", address: "9365 S Main St, Houston, TX 77025", latitude: 0, longitude: 0 }], vibeTags: ["Late Night", "Cash Friendly", "No Frills"], isMobileVenue: true },
  { id: "hou-12", cityId: "houston", name: "Crave Suya", cuisine: "West African", imageUrl: "placeholder://restaurant", description: "Nigerian suya done right, from a food truck that draws lines across Houston. Spicy grilled beef skewers with yaji seasoning.", rank: 3, voteCount: 0, priceLevel: 1, locations: [{ name: "Richmond Ave", address: "8633 Richmond Ave, Houston, TX 77063", latitude: 0, longitude: 0 }], vibeTags: ["Flavor Bomb", "Hidden Gem", "Cash Friendly"], isMobileVenue: true },
  { id: "hou-13", cityId: "houston", name: "The Peri Peri Factory", cuisine: "Portuguese-African (Peri Peri Chicken)", imageUrl: "placeholder://restaurant", description: "Flame-grilled peri peri chicken with sauces from mild to extra hot. Houston first. Halal-certified.", rank: 4, voteCount: 0, priceLevel: 2, locations: [{ name: "Westheimer", address: "6375 Westheimer Rd, Houston, TX 77057", latitude: 0, longitude: 0 }], vibeTags: ["Spicy", "Halal", "Casual"] },
  { id: "hou-9", cityId: "houston", name: "Corkscrew BBQ", cuisine: "BBQ", imageUrl: "placeholder://restaurant", description: "Pitmaster Will Buckman cooks over all-wood fires. Michelin-starred in 2024. Get there early or eat somewhere else.", rank: 5, voteCount: 0, priceLevel: 2, locations: [{ name: "Spring", address: "26608 Keith St, Spring, TX 77373", latitude: 0, longitude: 0 }], vibeTags: ["Worth the Drive", "No Frills", "Cash Friendly"] },
  { id: "hou-4", cityId: "houston", name: "Lost and Found", cuisine: "Cocktail Bar + Kitchen", imageUrl: "placeholder://restaurant", description: "A lively Midtown bar with colorful craft cocktails, a downtown-view patio, and a famous Travis Scott mural.", rank: 6, voteCount: 0, priceLevel: 3, locations: [{ name: "Midtown", address: "160 W Gray St, Houston, TX 77019", latitude: 0, longitude: 0 }], vibeTags: ["Good Drinks", "Lively", "Patio Views"] },
  { id: "hou-14", cityId: "houston", name: "Top Sushi", cuisine: "Japanese (Sushi)", imageUrl: "placeholder://restaurant", description: "Creative sushi rolls and fresh-cut fish on Westheimer. Known for signature rolls with bold flavor combos.", rank: 7, voteCount: 0, priceLevel: 2, locations: [{ name: "Westheimer", address: "8401 Westheimer Rd, Ste 160, Houston, TX 77063", latitude: 0, longitude: 0 }], vibeTags: ["Date Night", "Group Friendly", "Good Drinks"] },
  { id: "hou-15", cityId: "houston", name: "The Better Box", cuisine: "Comfort Food (Food Truck)", imageUrl: "placeholder://restaurant", description: "A food truck turning out loaded comfort-food boxes that punch above their price point.", rank: 8, voteCount: 0, priceLevel: 1, locations: [{ name: "Cypress Creek", address: "6560 Cypress Creek Pkwy, Houston, TX 77069", latitude: 0, longitude: 0 }], vibeTags: ["Comfort Food", "Cash Friendly", "Hidden Gem"], isMobileVenue: true },
  { id: "hou-16", cityId: "houston", name: "Joey Uptown", cuisine: "Globally-Inspired New American", imageUrl: "placeholder://restaurant", description: "A 10,000-square-foot Galleria restaurant with fire-torched sushi, steaks, and a temperature-controlled patio. Part of the JOEY chain.", rank: 9, voteCount: 0, priceLevel: 3, locations: [{ name: "Galleria / Uptown", address: "5045 Westheimer Rd, Ste X01, Houston, TX 77056", latitude: 0, longitude: 0 }], vibeTags: ["Date Night", "Group Friendly", "Trendy"] },
  { id: "hou-17", cityId: "houston", name: "Lotus Seafood", cuisine: "Cajun Seafood", imageUrl: "placeholder://restaurant", description: "Houston-born Cajun seafood by the pound since 2006. Five locations. Famous for the Crack Sauce.", rank: 10, voteCount: 0, priceLevel: 2, locations: [{ name: "Southwest Freeway", address: "9531 SW Fwy, Houston, TX 77074", latitude: 0, longitude: 0 }], vibeTags: ["Flavor Bomb", "Group Friendly", "Casual"] },
  // NYC (abbreviated IDs for brevity, full data)
  { id: "nyc-1", cityId: "nyc", name: "Peter Luger", cuisine: "Steakhouse", imageUrl: "https://images.unsplash.com/photo-1544025162-d76694265947?w=800", description: "Cash only, no menu needed. Porterhouse for two since 1887.", rank: 1, voteCount: 3241, priceLevel: 4, locations: [{ name: "Williamsburg", address: "178 Broadway, Brooklyn, NY 11211", latitude: 0, longitude: 0 }], vibeTags: ["Iconic", "Special Occasion", "Old School"] },
  { id: "nyc-2", cityId: "nyc", name: "Di Fara Pizza", cuisine: "Pizza", imageUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800", description: "Dom DeMarco has been hand-cutting basil on every slice since 1965.", rank: 2, voteCount: 2876, priceLevel: 2, locations: [{ name: "Midwood", address: "1424 Avenue J, Brooklyn, NY 11230", latitude: 0, longitude: 0 }], vibeTags: ["Iconic", "Cash Only", "Worth the Wait"] },
  { id: "nyc-3", cityId: "nyc", name: "Los Tacos No. 1", cuisine: "Mexican", imageUrl: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800", description: "Proof that a taco stand in a food hall can be world-class.", rank: 3, voteCount: 2654, priceLevel: 1, locations: [{ name: "Chelsea Market", address: "75 9th Ave, New York, NY 10011", latitude: 0, longitude: 0 }], vibeTags: ["Quick Bite", "Cash Friendly", "No Frills"] },
  { id: "nyc-4", cityId: "nyc", name: "Katz's Delicatessen", cuisine: "Deli", imageUrl: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800", description: "Do not lose your ticket. The pastrami has been perfect since 1888.", rank: 4, voteCount: 2432, priceLevel: 2, locations: [{ name: "Lower East Side", address: "205 E Houston St, New York, NY 10002", latitude: 0, longitude: 0 }], vibeTags: ["Iconic", "Tourist Worthy", "Old School"] },
  { id: "nyc-5", cityId: "nyc", name: "Xi'an Famous Foods", cuisine: "Chinese", imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800", description: "Hand-pulled noodles and cumin lamb that built an empire from a basement.", rank: 5, voteCount: 2198, priceLevel: 1, locations: [{ name: "Multiple locations", address: "Various, New York, NY", latitude: 0, longitude: 0 }], vibeTags: ["Cash Friendly", "Quick Bite", "Flavor Bomb"] },
  { id: "nyc-6", cityId: "nyc", name: "Joe's Pizza", cuisine: "Pizza", imageUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800", description: "The quintessential New York slice.", rank: 6, voteCount: 1987, priceLevel: 1, locations: [{ name: "Greenwich Village", address: "7 Carmine St, New York, NY 10014", latitude: 0, longitude: 0 }], vibeTags: ["Late Night", "Quick Bite", "Iconic"] },
  { id: "nyc-7", cityId: "nyc", name: "Russ & Daughters", cuisine: "Jewish Deli", imageUrl: "https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800", description: "Smoked fish and bagels, family-run since 1914.", rank: 7, voteCount: 1765, priceLevel: 2, locations: [{ name: "Lower East Side", address: "179 E Houston St, New York, NY 10002", latitude: 0, longitude: 0 }], vibeTags: ["Breakfast Spot", "Old School", "Iconic"] },
  { id: "nyc-8", cityId: "nyc", name: "Sushi Nakazawa", cuisine: "Japanese", imageUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800", description: "Jiro Dreams of Sushi graduate. Omakase perfection.", rank: 8, voteCount: 1543, priceLevel: 4, locations: [{ name: "West Village", address: "23 Commerce St, New York, NY 10014", latitude: 0, longitude: 0 }], vibeTags: ["Special Occasion", "Omakase", "Date Night"] },
  { id: "nyc-9", cityId: "nyc", name: "Lucali", cuisine: "Pizza", imageUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800", description: "BYOB, cash only, no slices. The pizza speaks for itself.", rank: 9, voteCount: 1321, priceLevel: 2, locations: [{ name: "Carroll Gardens", address: "575 Henry St, Brooklyn, NY 11231", latitude: 0, longitude: 0 }], vibeTags: ["BYOB", "Worth the Wait", "Neighborhood Favorite"] },
  { id: "nyc-10", cityId: "nyc", name: "Levain Bakery", cuisine: "Bakery", imageUrl: "https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800", description: "Cookies the size of your fist. Gooey center, crispy outside.", rank: 10, voteCount: 1198, priceLevel: 1, locations: [{ name: "Upper West Side", address: "167 W 74th St, New York, NY 10023", latitude: 0, longitude: 0 }], vibeTags: ["Quick Bite", "Sweet Tooth", "Tourist Worthy"] },
  // LA
  { id: "la-1", cityId: "la", name: "Guerrilla Tacos", cuisine: "Mexican", imageUrl: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800", description: "Chef Wes Avila turned a taco cart into an LA institution.", rank: 1, voteCount: 2567, priceLevel: 2, locations: [{ name: "Arts District", address: "2000 E 7th St, Los Angeles, CA 90021", latitude: 0, longitude: 0 }], vibeTags: ["Chef-Driven", "Casual", "Adventurous"] },
  { id: "la-2", cityId: "la", name: "Howlin' Ray's", cuisine: "Hot Chicken", imageUrl: "https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=800", description: "Nashville hot chicken that makes Angelenos wait 3 hours happily.", rank: 2, voteCount: 2345, priceLevel: 2, locations: [{ name: "Chinatown", address: "727 N Broadway, Los Angeles, CA 90012", latitude: 0, longitude: 0 }], vibeTags: ["Worth the Wait", "Spicy", "Loud and Fun"] },
  { id: "la-3", cityId: "la", name: "Bestia", cuisine: "Italian", imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800", description: "Industrial-chic Italian that still requires booking weeks out.", rank: 3, voteCount: 2123, priceLevel: 3, locations: [{ name: "Arts District", address: "2121 E 7th Pl, Los Angeles, CA 90021", latitude: 0, longitude: 0 }], vibeTags: ["Date Night", "Group Friendly", "Trendy"] },
  { id: "la-4", cityId: "la", name: "Jitlada", cuisine: "Thai", imageUrl: "https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=800", description: "Southern Thai food that does not compromise on spice. Jonathan Gold approved.", rank: 4, voteCount: 1876, priceLevel: 2, locations: [{ name: "Thai Town", address: "5233 Sunset Blvd, Los Angeles, CA 90027", latitude: 0, longitude: 0 }], vibeTags: ["Hidden Gem", "Spicy", "Flavor Bomb"] },
  { id: "la-5", cityId: "la", name: "Sugarfish", cuisine: "Japanese", imageUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800", description: "Kazunori Nozawa's approachable omakase. 'Trust Me' is the only order.", rank: 5, voteCount: 1654, priceLevel: 3, locations: [{ name: "Multiple locations", address: "Various, Los Angeles, CA", latitude: 0, longitude: 0 }], vibeTags: ["Omakase", "Date Night", "Clean Vibes"] },
  { id: "la-6", cityId: "la", name: "Langer's Deli", cuisine: "Deli", imageUrl: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800", description: "The #19 pastrami sandwich might be better than Katz's. We said it.", rank: 6, voteCount: 1432, priceLevel: 2, locations: [{ name: "Westlake", address: "704 S Alvarado St, Los Angeles, CA 90057", latitude: 0, longitude: 0 }], vibeTags: ["Old School", "Lunch Only", "Iconic"] },
  { id: "la-7", cityId: "la", name: "Mariscos Jalisco", cuisine: "Mexican Seafood", imageUrl: "https://images.unsplash.com/photo-1559847844-5315695dadae?w=800", description: "A taco truck that won a James Beard Award. Crispy shrimp tacos.", rank: 7, voteCount: 1298, priceLevel: 1, locations: [{ name: "Boyle Heights", address: "3040 E Olympic Blvd, Los Angeles, CA 90023", latitude: 0, longitude: 0 }], vibeTags: ["Cash Only", "Street Food", "No Frills"] },
  { id: "la-8", cityId: "la", name: "Petit Trois", cuisine: "French", imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800", description: "Ludo Lefebvre's no-reservations French bistro. 25 seats.", rank: 8, voteCount: 1156, priceLevel: 3, locations: [{ name: "Mid-Wilshire", address: "718 N Highland Ave, Los Angeles, CA 90038", latitude: 0, longitude: 0 }], vibeTags: ["Solo Dining", "Chef-Driven", "Cozy"] },
  { id: "la-9", cityId: "la", name: "Pine & Crane", cuisine: "Taiwanese", imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800", description: "Silver Lake Taiwanese that makes dan dan noodles worth crossing town for.", rank: 9, voteCount: 1034, priceLevel: 2, locations: [{ name: "Silver Lake", address: "1521 Griffith Park Blvd, Los Angeles, CA 90026", latitude: 0, longitude: 0 }], vibeTags: ["Neighborhood Favorite", "Casual", "Cash Friendly"] },
  { id: "la-10", cityId: "la", name: "Porto's Bakery", cuisine: "Cuban Bakery", imageUrl: "https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800", description: "Cuban bakery chain where the cheese rolls cause actual stampedes.", rank: 10, voteCount: 987, priceLevel: 1, locations: [{ name: "Multiple locations", address: "Various, Los Angeles, CA", latitude: 0, longitude: 0 }], vibeTags: ["Sweet Tooth", "Cash Friendly", "Big Portions"] },
  // Chicago
  { id: "chi-1", cityId: "chicago", name: "Alinea", cuisine: "Molecular Gastronomy", imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800", description: "Grant Achatz's three-Michelin-star temple of creativity. Dining as performance art.", rank: 1, voteCount: 2987, priceLevel: 4, locations: [{ name: "Lincoln Park", address: "1723 N Halsted St, Chicago, IL 60614", latitude: 0, longitude: 0 }], vibeTags: ["Special Occasion", "Adventurous", "Chef-Driven"] },
  { id: "chi-2", cityId: "chicago", name: "Portillo's", cuisine: "Hot Dogs", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800", description: "Chicago institution. Italian beef and hot dogs that define the city.", rank: 2, voteCount: 2765, priceLevel: 1, locations: [{ name: "Multiple locations", address: "Various, Chicago, IL", latitude: 0, longitude: 0 }], vibeTags: ["Iconic", "Cash Friendly", "Big Portions"] },
  { id: "chi-3", cityId: "chicago", name: "Lou Malnati's", cuisine: "Pizza", imageUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800", description: "Deep dish done right. Butter crust, sausage patty, chunky tomato.", rank: 3, voteCount: 2543, priceLevel: 2, locations: [{ name: "Multiple locations", address: "Various, Chicago, IL", latitude: 0, longitude: 0 }], vibeTags: ["Iconic", "Group Friendly", "Tourist Worthy"] },
  { id: "chi-4", cityId: "chicago", name: "Girl & The Goat", cuisine: "Modern American", imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800", description: "Stephanie Izard's flagship. Bold flavors, every dish fights for your attention.", rank: 4, voteCount: 2321, priceLevel: 3, locations: [{ name: "West Loop", address: "809 W Randolph St, Chicago, IL 60607", latitude: 0, longitude: 0 }], vibeTags: ["Chef-Driven", "Date Night", "Trendy"] },
  { id: "chi-5", cityId: "chicago", name: "Smoque BBQ", cuisine: "BBQ", imageUrl: "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800", description: "Texas-style BBQ in Chicago that Texans actually respect.", rank: 5, voteCount: 2098, priceLevel: 2, locations: [{ name: "Irving Park", address: "3800 N Pulaski Rd, Chicago, IL 60641", latitude: 0, longitude: 0 }], vibeTags: ["No Frills", "Worth the Wait", "Casual"] },
  { id: "chi-6", cityId: "chicago", name: "Au Cheval", cuisine: "Burgers", imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800", description: "The burger that launched a thousand wait lists. Single or double, both legendary.", rank: 6, voteCount: 1876, priceLevel: 2, locations: [{ name: "West Loop", address: "800 W Randolph St, Chicago, IL 60607", latitude: 0, longitude: 0 }], vibeTags: ["Worth the Wait", "Late Night", "Iconic"] },
  { id: "chi-7", cityId: "chicago", name: "Dove's Luncheonette", cuisine: "Tex-Mex", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800", description: "Retro Tex-Mex diner with vinyl playing and mezcal flowing.", rank: 7, voteCount: 1654, priceLevel: 2, locations: [{ name: "Wicker Park", address: "1545 N Damen Ave, Chicago, IL 60622", latitude: 0, longitude: 0 }], vibeTags: ["Brunch Spot", "Cozy", "Good Drinks"] },
  { id: "chi-8", cityId: "chicago", name: "Jim's Original", cuisine: "Hot Dogs", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800", description: "Maxwell Street Polish sausage stand, open since 1939. Cash, no frills.", rank: 8, voteCount: 1432, priceLevel: 1, locations: [{ name: "University Village", address: "1250 S Union Ave, Chicago, IL 60607", latitude: 0, longitude: 0 }], vibeTags: ["Late Night", "Cash Only", "Street Food"] },
  { id: "chi-9", cityId: "chicago", name: "Kasama", cuisine: "Filipino", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800", description: "First Filipino restaurant to earn a Michelin star. Bakery by day, tasting menu by night.", rank: 9, voteCount: 1287, priceLevel: 3, locations: [{ name: "Ukrainian Village", address: "1001 N Winchester Ave, Chicago, IL 60622", latitude: 0, longitude: 0 }], vibeTags: ["Chef-Driven", "Breakfast Spot", "Hidden Gem"] },
  { id: "chi-10", cityId: "chicago", name: "Mister D's", cuisine: "Diner", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800", description: "Old-school Chicago diner. Greek owners, massive portions, bottomless coffee.", rank: 10, voteCount: 1098, priceLevel: 1, locations: [{ name: "South Loop", address: "2 E Roosevelt Rd, Chicago, IL 60605", latitude: 0, longitude: 0 }], vibeTags: ["Old School", "Big Portions", "Breakfast Spot"] },
];

// Insider notes (subcollection data)
const insiderNotes = {
  "hou-1": { restaurantId: "hou-1", whatToOrder: "The Wagyu Texas BBQ Tantanmen (smoked A5 beef). Matcha Duck Ramen for something different.", insiderTip: "No reservations and lines form. Go off-peak, around 4 PM." },
  "hou-9": { restaurantId: "hou-9", whatToOrder: "Brisket, beef ribs, and the garlic sausage links.", insiderTip: "Arrive by 10 AM on weekends or the brisket is gone." },
  "hou-4": { restaurantId: "hou-4", whatToOrder: "Craft cocktails and shareable plates on the patio.", insiderTip: "The patio with the downtown skyline view is the spot." },
  "nyc-1": { restaurantId: "nyc-1", whatToOrder: "Porterhouse for two. German fried potatoes. Creamed spinach.", insiderTip: "Reservations book 30 days out. Call at exactly noon." },
  "nyc-2": { restaurantId: "nyc-2", whatToOrder: "Square slice. Period.", insiderTip: "Cash only. The square slice is the move." },
  "nyc-3": { restaurantId: "nyc-3", whatToOrder: "Adobada taco with everything. Horchata to drink.", insiderTip: "Get the adobada. Skip the line at lunch, go at 3 PM." },
  "nyc-4": { restaurantId: "nyc-4", whatToOrder: "Pastrami on rye with mustard. Nothing else.", insiderTip: "Tip the cutter and they will hook you up with extra meat." },
  "nyc-5": { restaurantId: "nyc-5", whatToOrder: "Spicy cumin lamb hand-pulled noodles.", insiderTip: "Spicy level 1 is already intense. You have been warned." },
  "nyc-6": { restaurantId: "nyc-6", whatToOrder: "Plain cheese slice, folded.", insiderTip: "Late night after bars is the real experience." },
  "nyc-7": { restaurantId: "nyc-7", whatToOrder: "Classic bagel with lox, cream cheese, capers, onions.", insiderTip: "The cafe on Orchard St has seating, the original is counter only." },
  "nyc-8": { restaurantId: "nyc-8", whatToOrder: "Omakase. There is no other option.", insiderTip: "Book exactly 30 days ahead via Resy." },
  "nyc-9": { restaurantId: "nyc-9", whatToOrder: "Plain pie with calzone on the side.", insiderTip: "Line up by 4:30 PM. Bring your own wine." },
  "nyc-10": { restaurantId: "nyc-10", whatToOrder: "Dark chocolate peanut butter cookie.", insiderTip: "Go early. They sell out of dark chocolate peanut butter by noon." },
  "la-1": { restaurantId: "la-1", whatToOrder: "Sweet potato taco and the tuna tostada.", insiderTip: "The sweet potato taco is unexpectedly the star." },
  "la-2": { restaurantId: "la-2", whatToOrder: "Sando at Medium with slaw and pickles.", insiderTip: "Howlin is not a joke. Start at Medium your first time." },
  "la-3": { restaurantId: "la-3", whatToOrder: "Spaghetti rustichella, bone marrow, any pizza.", insiderTip: "Reservations drop at midnight on Resy, 30 days ahead." },
  "la-4": { restaurantId: "la-4", whatToOrder: "Crying Tiger beef, morning glory, jazz fried rice.", insiderTip: "Order from the Southern Thai menu, not the regular one." },
  "la-5": { restaurantId: "la-5", whatToOrder: "Trust Me menu. Always.", insiderTip: "No modifications, no soy sauce. Trust the chef." },
  "la-6": { restaurantId: "la-6", whatToOrder: "#19 pastrami with coleslaw and swiss on rye.", insiderTip: "Lunch only. They close at 4 PM." },
  "la-7": { restaurantId: "la-7", whatToOrder: "Tacos dorados de camaron. Multiple.", insiderTip: "Cash only. Get there before the line wraps." },
  "la-8": { restaurantId: "la-8", whatToOrder: "Omelette, double cheeseburger, and the Big Mec.", insiderTip: "Go solo and sit at the bar. It is the best seat." },
  "la-9": { restaurantId: "la-9", whatToOrder: "Dan dan noodles, beef roll, three cup chicken.", insiderTip: "Their three cup chicken is underrated." },
  "la-10": { restaurantId: "la-10", whatToOrder: "Cheese rolls (a dozen), guava and cheese pastry, potato ball.", insiderTip: "Order online for pickup. The in-store line is brutal." },
  "chi-1": { restaurantId: "chi-1", whatToOrder: "The Gallery menu. You do not choose. You experience.", insiderTip: "Tickets, not reservations. They sell out instantly. Set a calendar alert." },
  "chi-2": { restaurantId: "chi-2", whatToOrder: "Italian beef, dipped, hot. Chicago-style hot dog. Chocolate cake shake.", insiderTip: "Get the combo: Italian beef dipped with hot peppers plus a Chicago dog." },
  "chi-3": { restaurantId: "chi-3", whatToOrder: "Buttercrust deep dish with sausage.", insiderTip: "Order ahead. A real deep dish takes 45 minutes." },
  "chi-4": { restaurantId: "chi-4", whatToOrder: "Goat empanadas, hamachi crudo, wood oven pig face.", insiderTip: "The goat empanadas are a must. Do not skip them." },
  "chi-5": { restaurantId: "chi-5", whatToOrder: "Brisket and half rack of ribs. Mac and cheese.", insiderTip: "Get there before noon on weekends or brisket sells out." },
  "chi-6": { restaurantId: "chi-6", whatToOrder: "Double cheeseburger with egg and bacon.", insiderTip: "Put your name in before you want to eat. The wait is real." },
  "chi-7": { restaurantId: "chi-7", whatToOrder: "Fried chicken torta, elote, any mezcal cocktail.", insiderTip: "Brunch is chaos in the best way. The playlist alone is worth the wait." },
  "chi-8": { restaurantId: "chi-8", whatToOrder: "Maxwell Street Polish with grilled onions and sport peppers.", insiderTip: "3 AM after a night out is peak Jim's." },
  "chi-9": { restaurantId: "chi-9", whatToOrder: "Longanisa breakfast sandwich (day). Full tasting (night).", insiderTip: "Daytime bakery requires no reservation. Night tasting books out weeks ahead." },
  "chi-10": { restaurantId: "chi-10", whatToOrder: "Gyros plate, Greek omelet, slice of pie.", insiderTip: "The gyros plate is enough for two people." },
};

// ---- Main ----

async function dryRun(force) {
  let writeCount = 0;
  let overwriteCount = 0;
  let skipCount = 0;

  // Check cities
  for (const city of cities) {
    const doc = await db.collection("cities").doc(city.id).get();
    if (doc.exists && doc.data().createdAt) {
      if (force) { overwriteCount++; } else { skipCount++; }
    } else {
      writeCount++;
    }
  }

  // Check restaurants
  for (const r of restaurants) {
    const doc = await db.collection("restaurants").doc(r.id).get();
    if (doc.exists && doc.data().createdAt) {
      if (force) { overwriteCount++; } else { skipCount++; }
    } else {
      writeCount++;
    }
  }

  // Check insider notes
  for (const [restaurantId, notes] of Object.entries(insiderNotes)) {
    const doc = await db
      .collection("restaurants")
      .doc(restaurantId)
      .collection("insiderNotes")
      .doc("notes")
      .get();
    if (doc.exists) {
      if (force) { overwriteCount++; } else { skipCount++; }
    } else {
      writeCount++;
    }
  }

  return { writeCount, overwriteCount, skipCount };
}

async function seed(force) {
  const now = Timestamp.now();

  // Seed cities
  for (const city of cities) {
    const ref = db.collection("cities").doc(city.id);
    const doc = await ref.get();
    const exists = doc.exists && doc.data().createdAt;
    if (exists && !force) {
      console.log(`  SKIP city: ${city.id} (already exists)`);
      continue;
    }
    const createdAt = exists ? doc.data().createdAt : now;
    await ref.set({ ...city, createdAt, updatedAt: now });
    console.log(`  ${exists ? "OVERWRITE" : "WRITE"} city: ${city.id}`);
  }

  // Seed restaurants (without insider fields on the doc)
  for (const r of restaurants) {
    const ref = db.collection("restaurants").doc(r.id);
    const doc = await ref.get();
    const exists = doc.exists && doc.data().createdAt;
    if (exists && !force) {
      console.log(`  SKIP restaurant: ${r.id} (already exists)`);
      continue;
    }
    const createdAt = exists ? doc.data().createdAt : now;
    // Do NOT write insiderTip/whatToOrder to the restaurant doc.
    // Those live in the insiderNotes subcollection.
    await ref.set({ ...r, createdAt, updatedAt: now });
    console.log(`  ${exists ? "OVERWRITE" : "WRITE"} restaurant: ${r.id}`);
  }

  // Seed insider notes (subcollection)
  for (const [restaurantId, notes] of Object.entries(insiderNotes)) {
    const ref = db
      .collection("restaurants")
      .doc(restaurantId)
      .collection("insiderNotes")
      .doc("notes");
    const doc = await ref.get();
    if (doc.exists && !force) {
      console.log(`  SKIP insiderNotes: ${restaurantId} (already exists)`);
      continue;
    }
    await ref.set(notes);
    console.log(`  ${doc.exists ? "OVERWRITE" : "WRITE"} insiderNotes: ${restaurantId}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes("--force");
  const confirm = args.includes("--confirm");
  const projectId = admin.app().options.projectId || "(unknown)";

  console.log(`\nVouch seed script`);
  console.log(`Target project: ${projectId}`);
  if (force) console.log(`Mode: --force (overwrite all docs)`);
  console.log("");

  // Dry run first
  console.log("Scanning existing data...");
  const { writeCount, overwriteCount, skipCount } = await dryRun(force);

  console.log(`\n  Documents to write:     ${writeCount}`);
  console.log(`  Documents to overwrite: ${overwriteCount}`);
  console.log(`  Documents to skip:      ${skipCount}`);
  console.log(`  Total:                  ${writeCount + overwriteCount + skipCount}\n`);

  if (writeCount + overwriteCount === 0) {
    console.log("Nothing to seed. All documents already exist.");
    process.exit(0);
  }

  if (!confirm) {
    console.log(
      "This is a dry run. To execute, run with --confirm:\n" +
      `  node scripts/seed_production.js${force ? " --force" : ""} --confirm\n`
    );
    process.exit(0);
  }

  console.log("Seeding...\n");
  await seed(force);
  console.log("\nDone.");
  process.exit(0);
}

main().catch((err) => {
  console.error("Seed script failed:", err);
  process.exit(1);
});
