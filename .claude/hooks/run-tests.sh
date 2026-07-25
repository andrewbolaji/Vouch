#!/usr/bin/env bash
#
# Stop hook: run Vouch's real test suites and block finishing while any fail.
#
# Contract (see https://code.claude.com/docs/en/hooks):
#   exit 0, no stdout                             -> stop is allowed
#   exit 0, {"decision":"block","reason":...}     -> stop is blocked
#
# Design notes, all of them learned the hard way:
#
#   Fail closed, always. Every path that cannot verify the suites blocks. A
#   gate that fails open is worse than no gate, because it reads as green.
#
#   Never auto-release. An earlier version stood down after N blocks so a red
#   suite could not trap the session. That traded a fail-closed bug for a worse
#   fail-open one: a developer who left an emulator on port 8080 would burn the
#   budget on environment errors and then have the gate silently switched off
#   for the rest of the session. You cannot both guarantee termination and
#   guarantee red never ships. This gate chooses the latter, which is what the
#   repo's definition of done asks for. The escape is VOUCH_SKIP_TEST_HOOK=1,
#   or interrupting. The counter below only escalates wording, so an unwritable
#   TMPDIR degrades the message and never the gate.
#
#   Run everything, every time. An earlier version scoped suites to changed
#   paths. It was faster and wrong twice over: after commit and push the change
#   set is empty, so the gate no-opped on exactly the turn that claims green,
#   and any git failure produced an empty change set that also passed. Roughly
#   75 seconds per stop is the honest price.
#
#   Do not trust `command -v java`. macOS ships a stub at /usr/bin/java that
#   resolves fine and then refuses to run. Probe with `java -version`.
#
#   Check counts, not just exit status. A deleted or skipped test exits 0.
#   Suites may grow, so block only when a count falls below its baseline.
#
#   Say which failure this is. An environment problem is not a failing test,
#   and the message must not claim otherwise.

set -uo pipefail

# Baseline counts. Raise these when a suite legitimately grows.
EXPECT_FLUTTER=310
EXPECT_FUNCTIONS=63
EXPECT_RULES=79

# The documented escape hatch is checked first, before any dependency, so it
# still works on a machine missing them. It announces itself: a stale export in
# a shell profile must not disable the gate invisibly.
if [[ "${VOUCH_SKIP_TEST_HOOK:-0}" == "1" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"VOUCH_SKIP_TEST_HOOK=1 is set, so the test gate did NOT run. Do not describe the suites as passing unless you ran them yourself this turn."}}'
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
  PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
cd "$PROJECT_DIR" || {
  printf '{"decision":"block","reason":"Stop hook could not enter the project directory, so the suites did not run. Treat this work as unverified."}'
  exit 0
}

HOOK_INPUT="$(cat)"

SESSION_ID="nosession"
if command -v node >/dev/null 2>&1; then
  SESSION_ID="$(node -e '
    let raw = "";
    process.stdin.on("data", (d) => (raw += d));
    process.stdin.on("end", () => {
      try {
        const id = JSON.parse(raw).session_id;
        process.stdout.write(typeof id === "string" && id ? id.replace(/[^A-Za-z0-9_-]/g, "") : "nosession");
      } catch {
        process.stdout.write("nosession");
      }
    });
  ' <<<"$HOOK_INPUT" 2>/dev/null || echo nosession)"
fi
[[ -n "$SESSION_ID" ]] || SESSION_ID="nosession"

# Escalation only. Never gates whether we block, so a read-only TMPDIR is
# harmless here.
STATE_FILE="${TMPDIR:-/tmp}/vouch-test-hook-${SESSION_ID}.count"
BLOCKS="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
[[ "$BLOCKS" =~ ^[0-9]+$ ]] || BLOCKS=0
bump() { echo $((BLOCKS + 1)) >"$STATE_FILE" 2>/dev/null || true; }

nag() {
  (( BLOCKS >= 2 )) && printf ' This has now blocked %s times. If you cannot get the suites green, stop and tell the user what is failing rather than retrying: do not report this work as complete.' "$((BLOCKS + 1))"
}

block_static() {
  bump
  node -e '
    process.stdout.write(JSON.stringify({decision: "block", reason: process.argv[1] + process.argv[2]}));
  ' "$1" "$(nag)" 2>/dev/null || printf '{"decision":"block","reason":%s}' "$(printf '%s' "$1" | sed 's/"/\\"/g; s/^/"/; s/$/"/')"
  exit 0
}

# node parses JSON and tails logs. Missing node must block, never pass.
command -v node >/dev/null 2>&1 || {
  bump
  printf '{"decision":"block","reason":"The Stop hook needs node to run the test gate and node is not on PATH, so the suites did NOT run and this work is unverified. If node is managed by nvm or fnm, expose it to non-interactive shells, or set VOUCH_SKIP_TEST_HOOK=1 to bypass."}'
  exit 0
}

LOG_DIR="$(mktemp -d 2>/dev/null)"
[[ -n "$LOG_DIR" && -d "$LOG_DIR" ]] || block_static "The Stop hook could not create a temporary log directory, so the suites did NOT run. This is an environment problem, not a test failure."
trap 'rm -rf "$LOG_DIR"' EXIT

block() {
  local suite="$1" log="$2"
  bump
  node -e '
    const [suite, log, extra] = process.argv.slice(1);
    const fs = require("fs");
    let tail = "(log unavailable)";
    try {
      tail = fs.readFileSync(log, "utf8").trim().split("\n").slice(-40).join("\n");
    } catch {}
    process.stdout.write(JSON.stringify({
      decision: "block",
      reason: `${suite} is failing, so this work is not done. Fix it, then re-run.${extra}\n\n${tail}`,
    }));
  ' "$suite" "$log" "$(nag)" 2>/dev/null \
    || printf '{"decision":"block","reason":"%s is failing and the hook could not read its log. Re-run the suite manually."}' "$suite"
  exit 0
}

# Block when a suite shrinks. Growth is fine, silent disappearance is not.
check_count() {
  local suite="$1" actual="$2" expected="$3"
  [[ -n "$actual" ]] \
    || block_static "$suite exited 0 but the hook could not parse its test count, so it cannot confirm the suite still has $expected tests. Check the suite manually. This is a parsing problem, not necessarily a test failure."
  (( actual < expected )) \
    || return 0
  block_static "$suite reports $actual passing tests, down from a baseline of $expected. Tests were removed or skipped. Restore them, or raise the baseline in .claude/hooks/run-tests.sh with a reason."
}

# 1. Flutter suite, no emulator needed.
if ! flutter test >"$LOG_DIR/flutter.log" 2>&1; then
  block "flutter test" "$LOG_DIR/flutter.log"
fi
check_count "flutter test" \
  "$(grep -oE '\+[0-9]+' "$LOG_DIR/flutter.log" | tail -1 | tr -d '+')" "$EXPECT_FLUTTER"

# The emulator needs Java. Homebrew's openjdk is keg-only, so put it on PATH
# here rather than depending on whatever the launching shell happened to have.
for candidate in \
  "$(brew --prefix openjdk 2>/dev/null)/bin" \
  /usr/local/opt/openjdk/bin \
  /opt/homebrew/opt/openjdk/bin
do
  [[ -x "$candidate/java" ]] && { export PATH="$candidate:$PATH"; break; }
done

# /usr/bin/java exists on macOS with no JDK behind it, so probe by running it.
java -version >/dev/null 2>&1 \
  || block_static "No working Java runtime, so the Cloud Function and rules suites could not run and this work is unverified. No test has failed: this is an environment problem. Install a JDK with: brew install openjdk"

# A held emulator port fails to bind and reads exactly like a test failure in
# the log tail. Name it correctly instead.
for port in 8080 9099; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    block_static "Port $port is already in use, so the emulator suites could not run. No test has failed: something else is holding the port (another emulator, or a second Claude session). Free it and re-run, the tree may well be green."
  fi
done

# Jest prints "Tests: 2 skipped, 61 passed, 63 total", so match the passed
# count anywhere on the line rather than anchoring right after "Tests:".
jest_passed() {
  grep -E '^Tests:' "$1" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1
}

# 2. Cloud Function suite.
if ! firebase emulators:exec --only firestore,auth --project vouch-test \
  'cd functions && npx jest --forceExit' >"$LOG_DIR/functions.log" 2>&1; then
  block "The Cloud Function suite" "$LOG_DIR/functions.log"
fi
check_count "The Cloud Function suite" "$(jest_passed "$LOG_DIR/functions.log")" "$EXPECT_FUNCTIONS"

# 3. Firestore rules suite.
if ! npm --prefix test-rules run test:emulator >"$LOG_DIR/rules.log" 2>&1; then
  block "The Firestore rules suite" "$LOG_DIR/rules.log"
fi
check_count "The Firestore rules suite" "$(jest_passed "$LOG_DIR/rules.log")" "$EXPECT_RULES"

rm -f "$STATE_FILE" 2>/dev/null
exit 0
