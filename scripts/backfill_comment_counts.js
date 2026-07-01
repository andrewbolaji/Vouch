/**
 * One-time backfill: set commentCount on each restaurant doc
 * by counting its comments subcollection.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *   node scripts/backfill_comment_counts.js
 *
 * Or against the emulator:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   node scripts/backfill_comment_counts.js
 */

const {initializeApp, cert} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const cred = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (cred) {
  initializeApp({credential: cert(cred)});
} else {
  initializeApp({projectId: "vouch-dev"});
}

const db = getFirestore();

async function backfill() {
  const restaurants = await db.collection("restaurants").get();
  let updated = 0;

  for (const snap of restaurants.docs) {
    const comments = await snap.ref.collection("comments").count().get();
    const count = comments.data().count;
    await snap.ref.update({commentCount: count});
    console.log(`${snap.id}: commentCount = ${count}`);
    updated++;
  }

  console.log(`Done. Updated ${updated} restaurant(s).`);
}

backfill().catch((err) => {
  console.error(err);
  process.exit(1);
});
