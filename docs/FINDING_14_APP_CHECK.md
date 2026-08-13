# Finding 14: App Check is not enforced

**Launch blocking.** Not a hygiene item.

Every number in the Fix B manipulation table assumes a vote costs a
person. With App Check unenforced, a vote costs an email address. The
Firestore API accepts writes without any proof that the caller is the
real app, and a verified email is the only remaining friction, which
disposable and relay addresses reduce to close to nothing.

`firestore.rules:82` enforcing `weight == 1` is correct and it
protects nothing if the caller is a script. "Locals decide" and "money
cannot buy rank" both fail completely if the vote endpoint accepts
traffic that did not come from the app.

Report only. Nothing was enabled.

## Measured state

Read from the App Check Admin API against `majorcitymusteats`, not
from the console and not from the repo.

| Service | Enforcement |
|---|---|
| `firestore.googleapis.com` | **UNENFORCED** |
| `identitytoolkit.googleapis.com` (Auth) | **UNENFORCED** |
| `oauth2.googleapis.com` | **UNENFORCED** |
| `places.googleapis.com` | **UNENFORCED** |

Last updated `2026-08-10T21:38:23Z`, which is when the services were
registered. Nothing has been enforced since.

`cloudfunctions.googleapis.com` does not appear in that list, and its
absence is expected rather than a gap: callable enforcement is a
per-function option (`enforceAppCheck`) in the function definition,
not a project-level service toggle. A repo-wide search returns **zero
matches** for `enforceAppCheck` in `functions/src/`.

**iOS app registration** `com.thunderrivertech.vouch`:

| | |
|---|---|
| `appAttestConfig` | present, `tokenTtl: 3600s` |
| `deviceCheckConfig` | present, `tokenTtl: 3600s` |
| `debugTokens` | **empty**, confirmed again 2026-08-13 via `scripts/register_app_check_debug_token.js --list` |

## 1. What breaks if enforcement is turned on

### Firestore: nothing breaks. This is the one that matters.

`cloud_firestore` attaches an App Check token automatically once
`FirebaseAppCheck.instance.activate()` has run, which it does at
`lib/main.dart:35`. No client change is needed.

This is also the surface that protects votes, because the client
writes vote documents directly (`vote_repository.dart:37`). Enforcing
Firestore is most of the value of this finding.

### Both callables break immediately. This is the blocker.

`cloud_functions` is **not in `pubspec.yaml` at all.** Both callables
are invoked by hand-rolled HTTP POST:

- `lib/repositories/comment_repository.dart:146`
- `lib/repositories/suggestion_repository.dart:53`

Both send exactly two headers, `Authorization: Bearer <idToken>` and
`Content-Type`. **Neither sends `X-Firebase-AppCheck`,** because
nothing attaches it: the token is attached by the Functions SDK,
which is not present.

So turning on `enforceAppCheck` for `submitComment` or
`submitSuggestion` today stops commenting and suggestions working for
every user, immediately and totally. This is certain, not a risk.

Two ways to fix, and the second is smaller:

1. Add `cloud_functions` and switch to `httpsCallable`, which attaches
   the token. Larger: it replaces the existing hand-rolled error
   mapping in both repositories, and that mapping is load bearing
   (`submitComment` returns four distinct error codes the client
   distinguishes, including `aborted` for a missing display name).
2. Keep the raw POST and add the header from
   `FirebaseAppCheck.instance.getToken()`. Smaller, preserves the
   error handling, and is the recommendation.

### Two endpoints must NOT be enforced, ever

| Endpoint | Caller | Consequence of enforcing |
|---|---|---|
| `waitlistSignup` | **The marketing site.** `site/index.html:321` calls it with a plain `fetch`. | vouchfood.com's signup form stops working. |
| `onRevenueCatWebhook` | **RevenueCat's servers.** | Entitlement webhooks stop arriving. Users pay and never get the tier. |

Neither is the app, so neither can ever present an App Check token.
Worth writing down because "turn on App Check" reads like a
project-wide switch, and applied that way it would break the
subscription pipeline.

### Scripts and tests: unaffected

All 17 admin scripts go through `initAdminApp()`, and the Admin SDK
bypasses App Check by design, as it does security rules. Nothing in
`scripts/` would start failing.

No test touches production. The two test files that mention the
production URL
(`test/repositories/suggestion_repository_test.dart:55`,
`comment_repository_test.dart:278`) assert against a **mock**
`httpClient` and make no network call. The functions and rules suites
run against `127.0.0.1:8080`.

### Does App Attest actually issue tokens on a real device?

**Yes, measured.** Cloud Monitoring,
`firebaseappcheck.googleapis.com/services/verification_count`, last 30
days:

| app_id | security | result | count |
|---|---|---|---|
| `1:400845601317:ios:...a05dcc` | `VALID` | `ALLOW` | **8** |

One series only. Zero `INVALID`, zero `MISSING`. So the App Attest
configuration works end to end on a real device, and this is not a
theoretical rollout.

## 2. What the rollout looks like

**Honest reading of the metric: 8 of 8 valid is 100%, and 8 is not a
sample.** There are 4 users, 1 waitlist row, 0 suggestions, 0 reports,
and no city is live. That volume is consistent with Andrew testing on
his own device, and it is the entire production traffic history.

So the metric proves **capability**, that a real device can obtain and
present a valid token, and it does not prove **coverage**, that all
real traffic would pass. There is not enough traffic for the second
question to have an answer yet.

One thing the 8 do not cover: those raw HTTP calls to the two
callables are not App Check aware today, so they were never counted.
The absence of `MISSING` verdicts is not evidence that those two paths
are fine. It is evidence that App Check never saw them.

**Recommended order, which does not depend on more traffic:**

1. **Register a debug token** (see below). Without this, step 2 locks
   the simulator out.
2. **Add the `X-Firebase-AppCheck` header to both repositories.**
   Ship it. It is inert while everything is unenforced, so it can go
   out well ahead of any enforcement and be verified in monitor mode.
3. **Enforce `firestore.googleapis.com` first**, alone. It is the
   surface that protects votes, needs no client change, and is the
   one with a measured working provider.
4. Watch `verdict_count` for `INVALID` or `MISSING` series appearing.
   Today there is exactly one series and it is `VALID/ALLOW`, so any
   new series is a signal rather than noise.
5. **Then `enforceAppCheck: true` on the two callables**, only after
   step 2 has been on a real device and shown up in the metric.
6. `identitytoolkit` (Auth) last, and separately, because locking
   yourself out of sign-in is the failure with no in-app recovery.

Steps 1 and 2 are unblocked now and are the only code changes.

## 3. Debug tokens

**None are registered.** `debugTokens` returns `{}`.

`scripts/register_app_check_debug_token.js` provisions one. It has
been written and its read path verified (`--list` reports 0), and it
has **deliberately not been run**. Two reasons. The value it returns
is a credential that bypasses attestation entirely, and running it
here would print that credential into a session transcript. And a
debug token is per developer machine: one created from this machine
does not help the Xcode scheme on Andrew's. He runs `--create` when
he is at the machine that needs it, and it goes in the scheme's
environment variables, never in the repo.

`lib/main.dart:37` already selects the debug provider under
`kDebugMode`:

```dart
appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
```

That is correct and compiled out of release. But a debug provider
still needs its generated token **registered against the app** before
the backend will accept it, and nothing is registered. So the moment
Firestore is enforced, every simulator run and every debug device
starts failing its reads and writes.

Where they live:

- **Simulator and local debug.** The Firebase SDK prints a generated
  debug token to the Xcode console on first run. It gets registered
  once per machine via the App Check page, or the API. It is a
  credential: it must not be committed, and it belongs in the
  developer's own environment.
- **CI.** `.github/workflows` runs `flutter test` and the golden
  build. Neither touches Firebase (goldens mock `path_provider` and
  swap sqflite for FFI, and no unit test constructs a real Firebase
  app), so **CI needs no debug token today.** It would only need one
  if an integration test against a real project is ever added, and at
  that point the token belongs in repository secrets, never in the
  workflow file.

Recording that CI does not need one is the point of checking. The
default assumption would have been that it does, and provisioning a
long-lived credential nothing uses is its own risk.

## Enforcement binds to external TestFlight, not to a date

**Recorded explicitly, because "enforce before launch" without this
invites somebody to flip it on a quiet Tuesday.**

The rollout above has a watch step, and today there is nothing to
watch. Four users, one waitlist row, no live city. A monitor window
opened now measures nothing, and enforcing on that basis would be a
decision made against noise rather than against traffic.

So the sequence is:

1. Ship the header and register a debug token. Both done or ready.
2. Get real devices onto an external TestFlight build carrying the
   header.
3. Read the verdict series **when there is a series to read.** Today
   there is exactly one, `VALID/ALLOW`, count 8. Any new series
   appearing, `INVALID` or `MISSING`, is signal rather than noise
   precisely because the baseline is that clean.
4. Enforce Firestore first and alone, before public launch.
5. Callables, then Auth last, because sign-in lockout has no in-app
   recovery.

Step 4 is gated on step 3 having actual data, not on a calendar date.

## Still open, read only

Two questions this report raised and did not answer. Both are read
only and neither is fixed.

**What protects `waitlistSignup`?** It is publicly callable,
unauthenticated, necessarily App Check exempt, and it writes to
Firestore. A script can write waitlist rows at whatever rate it
likes, which is a data quality problem and a billing one, since
Firestore writes cost money and nobody is watching the bill on a
pre-launch project.

**What is the exposure on `places.googleapis.com`?** It appears in
the unenforced list. Whether Places is called from the client at all,
and if so whether the key is restricted by bundle identifier and by
API or is a general key in a shipped binary. An unrestricted Places
key in a public app is a known abuse pattern, and the damage arrives
as an invoice rather than as an outage.

## Recommendation

Land steps 1 and 2 as one commit, before Storage: register a debug
token, and add the `X-Firebase-AppCheck` header to both repositories
so the app can survive enforcement. Both are inert until something is
enforced, so they carry no risk and they remove the only hard blocker.

Enforcement itself stays a deliberate, separately approved step.
