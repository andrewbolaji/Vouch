/**
 * Registers an App Check debug token for the iOS app.
 *
 * Why this is needed. `lib/main.dart` already selects
 * `AppleProvider.debug` under `kDebugMode`, correctly, and that is
 * compiled out of release. But a debug provider still needs its token
 * **registered against the app** before the backend will accept it,
 * and as of 2026-08-13 the project has none: the debugTokens
 * collection is empty. So the moment any service is enforced, every
 * simulator run and every debug device starts failing its reads and
 * writes, with no obvious cause.
 *
 * Why it is a script rather than a one-off console click. The step is
 * per developer machine and will be needed again, and doing it by
 * hand in a console is exactly the shape of the city publish problem:
 * an undocumented manual edit that works until the person who knew
 * about it is not there.
 *
 * THE TOKEN IS A CREDENTIAL. It bypasses attestation entirely for
 * whoever holds it. It must not be committed, must not be pasted into
 * a shared channel, and must not be reused across machines. It goes
 * in the Xcode scheme as an environment variable named
 * FIRAAppCheckDebugToken, which is per machine and not in the repo.
 *
 * CI does not need one. Nothing in .github/workflows touches
 * Firebase: the unit tests construct no real Firebase app, and the
 * golden harness mocks path_provider and swaps sqflite for FFI. Do
 * not provision a long lived credential for something that does not
 * use it. See docs/FINDING_14_APP_CHECK.md.
 *
 * Usage:
 *   node register_app_check_debug_token.js --list
 *   node register_app_check_debug_token.js --create "andrew-macbook"
 */

const { GoogleAuth } = require("google-auth-library");
const { resolvedProjectId, initAdminApp } = require("./lib/admin_app");

const APP_ID = "1:400845601317:ios:eca2a15ede7a0691a05dcc";

async function client() {
  return new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  }).getClient();
}

function base(projectId) {
  return "https://firebaseappcheck.googleapis.com/v1/projects/" +
    `${projectId}/apps/${encodeURIComponent(APP_ID)}/debugTokens`;
}

async function main() {
  const args = process.argv.slice(2);
  const projectId = resolvedProjectId(initAdminApp());
  const c = await client();

  console.log(`Project: ${projectId}`);
  console.log(`App:     ${APP_ID}`);
  console.log("");

  if (args.includes("--list") || args.length === 0) {
    const res = await c.request({ url: base(projectId) });
    const tokens = res.data.debugTokens || [];
    console.log(`Registered debug tokens: ${tokens.length}`);
    // Display names only. The token values are deliberately not
    // printed: this output goes into terminals, logs and transcripts.
    for (const t of tokens) {
      console.log(`  ${t.displayName}  (${t.name.split("/").pop()})`);
    }
    if (args.length === 0) {
      console.log("");
      console.log('Use --create "<machine name>" to register a new one.');
    }
    return;
  }

  const i = args.indexOf("--create");
  const displayName = i >= 0 ? args[i + 1] : null;
  if (!displayName) {
    console.error('Usage: --create "<machine name>"');
    process.exit(1);
  }

  const res = await c.request({
    url: base(projectId),
    method: "POST",
    data: { displayName },
  });

  console.log(`Created debug token "${res.data.displayName}".`);
  console.log("");
  console.log("Value (shown once here, treat it as a password):");
  console.log("");
  console.log(`  ${res.data.token}`);
  console.log("");
  console.log("Add it to the Xcode scheme, not to the repo:");
  console.log("  Product > Scheme > Edit Scheme > Run > Arguments");
  console.log("  Environment Variables: FIRAAppCheckDebugToken = <value>");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err.response?.data?.error?.message || err.message);
    process.exit(1);
  });
