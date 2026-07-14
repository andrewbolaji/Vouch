/**
 * RETIRED: This script created synthetic vote docs for the ranking engine.
 * It was used during pre-launch development and has been neutered to prevent
 * anyone from accidentally re-seeding fake votes into production.
 *
 * All synthetic vote docs were deleted by scripts/reset_votes.js before
 * launch. Real votes come from authenticated users only.
 *
 * If you need to test the ranking engine locally, use the Firestore emulator
 * and create vote docs there.
 */

console.error(
  "ERROR: seed_rank_votes.ts is retired. " +
  "Synthetic votes were cleared before launch and must not be re-created. " +
  "Use the Firestore emulator for ranking-engine testing."
);
process.exit(1);
