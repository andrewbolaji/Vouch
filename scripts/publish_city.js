/**
 * Publishes one named city, deliberately and idempotently.
 *
 * Setting a city live is a single field, `status`, and it is the
 * difference between a shipped app and a usable one. Both seed
 * writers were narrowed to create-only by commit bba62e0, correctly,
 * so publishing had become an undocumented manual edit in the
 * Firestore console with no checks and no coverage.
 *
 * The logic lives in lib/city_publisher.js, which is pure and tested
 * against an in-memory fake. This file is only the CLI: it resolves
 * the project, prints, and sets an exit code.
 *
 * Usage:
 *   node publish_city.js houston            # dry run, checks only
 *   node publish_city.js houston --confirm  # publish
 *
 * Exit codes:
 *   0  passed, or already live, or a clean dry run
 *   1  blocked, or the city was not named, or the write failed
 */

const { initAdminApp, resolvedProjectId } = require("./lib/admin_app");
const { publishCity } = require("./lib/city_publisher");

async function main() {
  const args = process.argv.slice(2);
  const confirm = args.includes("--confirm");
  const cityId = args.find((a) => !a.startsWith("--"));

  // One named city, never a loop over all of them. Publishing is the
  // most consequential single write in the system and it should not
  // be possible to do it to five cities by forgetting an argument.
  if (!cityId) {
    console.error("Usage: node publish_city.js <cityId> [--confirm]");
    process.exit(1);
  }

  const app = initAdminApp();
  const db = app.firestore();

  console.log(`Project: ${resolvedProjectId(app)}`);
  console.log(`City:    ${cityId}`);
  console.log(`Mode:    ${confirm ? "PUBLISH" : "dry run"}`);
  console.log("");

  const result = await publishCity(db, cityId, { confirm });
  const { check } = result;

  if (check.stats) {
    console.log(`  name:            ${check.stats.name}`);
    console.log(`  current status:  ${check.stats.currentStatus}`);
    console.log(`  restaurants:     ${check.stats.restaurants}`);
    console.log(`  with notes:      ${check.stats.withNotes}`);
    console.log(`  without image:   ${check.stats.withoutImage}`);
    console.log("");
  }

  if (check.warnings.length > 0) {
    console.log("Warnings (these do not block):");
    for (const w of check.warnings) console.log(`  ! ${w}`);
    console.log("");
  }

  if (check.blockers.length > 0) {
    console.error("BLOCKED:");
    for (const b of check.blockers) console.error(`  x ${b}`);
    console.error("");
    console.error("Nothing was written.");
    process.exit(1);
  }

  switch (result.reason) {
    case "already-live":
      console.log(`${cityId} is already live. Nothing to do.`);
      break;
    case "dry-run":
      console.log("All checks passed. Use --confirm to publish.");
      break;
    case "published":
      console.log(`${cityId} is now live. Verified by read-back.`);
      break;
    case "verify-failed":
      console.error("Write reported success but the read-back disagrees.");
      process.exit(1);
      break;
    default:
      console.error(`Unexpected result: ${result.reason}`);
      process.exit(1);
  }
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
