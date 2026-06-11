/**
 * One-time migration: backfill vote documents for existing restaurants
 * so the ranking engine has real vote docs with timestamps to decay.
 *
 * Creates a modest number of synthetic vote docs per restaurant (20-30),
 * weighted so higher-seeded restaurants get more and more-recent votes.
 * The existing voteCount on the restaurant doc is left untouched (it
 * stays as the cosmetic display number).
 *
 * Usage:
 *   npx ts-node scripts/seed_rank_votes.ts
 *
 * Requires FIRESTORE_EMULATOR_HOST or a service account.
 */

import {initializeApp, cert, getApps} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

if (getApps().length === 0) {
  // Use emulator if set, otherwise default credentials
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({projectId: "majorcitymusteats"});
  } else {
    initializeApp();
  }
}

const db = getFirestore();

/** Generate a date between daysAgoStart and daysAgoEnd before now. */
function randomDateInRange(daysAgoStart: number, daysAgoEnd: number): Date {
  const now = Date.now();
  const msPerDay = 24 * 60 * 60 * 1000;
  const startMs = now - daysAgoStart * msPerDay;
  const endMs = now - daysAgoEnd * msPerDay;
  return new Date(endMs + Math.random() * (startMs - endMs));
}

async function seedRankVotes() {
  const restaurantsSnap = await db.collection("restaurants").get();

  if (restaurantsSnap.empty) {
    console.log("No restaurants found. Run the main seed script first.");
    return;
  }

  let totalVotes = 0;

  for (const doc of restaurantsSnap.docs) {
    const data = doc.data();
    const rank = (data.rank as number) ?? 10;

    // Higher-ranked restaurants get more votes and more-recent ones.
    // Rank 1: 30 votes, mostly recent (0-30 days ago).
    // Rank 10: 15 votes, spread wider (0-60 days ago).
    const voteCount = Math.max(15, 35 - rank * 2);
    const recentDaysAgo = Math.min(60, 20 + rank * 4);

    const votesRef = doc.ref.collection("votes");
    const batch = db.batch();

    for (let i = 0; i < voteCount; i++) {
      const seedId = `seed-${doc.id}-${String(i).padStart(3, "0")}`;
      const voteDate = randomDateInRange(0, recentDaysAgo);
      batch.set(votesRef.doc(seedId), {
        createdAt: Timestamp.fromDate(voteDate),
        weight: 1,
      });
    }

    await batch.commit();
    totalVotes += voteCount;
    console.log(
      `  ${doc.id} (rank ${rank}): ${voteCount} seed votes ` +
      `(0-${recentDaysAgo} days ago)`
    );
  }

  console.log(`\nDone. Created ${totalVotes} seed vote documents.`);
  console.log(
    "Note: voteCount on restaurant docs is unchanged (cosmetic display)."
  );
}

seedRankVotes().catch(console.error);
