# Remediation state, 2026-08-13

Handover for an instance with no memory of this cycle. Specifics over
prose. Everything here was measured against code or production unless
it says otherwise.

## RESOLVED: the recompute is live again, and it ran

`recomputeRanks` was deleted from production on 2026-08-13 to stop it
alphabetizing Houston. Fix A (`9f0e512`) removed that risk, so it was
redeployed and **triggered directly** rather than left for 06:00 UTC:

```
firebase deploy --only functions:recomputeRanks --project majorcitymusteats
gcloud scheduler jobs run firebase-schedule-recomputeRanks-us-central1 \
  --project majorcitymusteats --location us-central1
```

`gcloud` has no logged-in account on this machine, only ADC. Minting
an access token from ADC and passing it as `CLOUDSDK_AUTH_ACCESS_TOKEN`
works and needs no interactive login.

**`displayOrder` was backfilled first**, deliberately, so the run had
exactly one effect. Chicago, LA and NYC carried it on 0 of 10
documents each; absent sorts last, so the run would have reordered
those 30 as well, and a measurement with a second moving part in it
is not a measurement. `scripts/backfill_display_order.js` wrote 30,
verified 57/57 by read-back, and a second run is a true no-op.

### Finding 9, closed on outcome

| | Before | After |
|---|---|---|
| sum of stored `voteCount` | **-797** | **0** |
| documents with negative `voteCount` | **33** | **0** |
| documents disagreeing with their votes subcollection | 33 | 0 |
| documents where `rank != displayOrder` | 0 | **0** |
| distinct `rankScore` values | mixed | `[0]` |

Order after the run, compared line by line against the snapshot taken
before it: **identical in all five cities.** Houston still reads
Mensho, Tacos Los Brothers, Crave Suya, The Peri Peri Factory,
Corkscrew BBQ, Lost and Found, Top Sushi, The Better Box, Joey
Uptown, Lotus Seafood.

That is Fix A proven in production rather than in a fixture. The same
run against the pre-fix engine would have alphabetized every city.

The absent-`displayOrder` branch is now dead in production, so
"absent sorts last" is a defensive path rather than a live one.

## Findings

| # | Status | Commit |
|---|---|---|
| 1 | Landed. VoteRepository never wired into AppState in main.dart, so votes never reached Firestore. Composition-root test added. | `57e7695` |
| 1 (failure path) | Landed. toggleVote awaits and rolls back; rules split get/list; cascade guard on applyVoteDeleted/applyCommentDeleted. | `1c7639a` |
| 2 | Landed. 33 generated notes deleted from production, and the wiring built so a real note renders when one exists. The gate at `restaurant_detail_screen.dart:669` read `restaurant.whatToOrder != null \|\| restaurant.insiderTip != null`, which `_parseRestaurant` makes permanently false, so nobody saw notes or the pitch for them, paid or free. Now driven by the entitlement (rules gate the subcollection on `isCityInsider()`, so a free client cannot discover whether notes exist, and a `hasInsiderNotes` flag is exactly the leak the subcollection prevents). Four states kept distinct: notes, empty, error with retry, locked. **Ships against nothing until Andrew writes real notes, which is the correct state.** | insiderNotes never load, and the outer gate at `restaurant_detail_screen.dart:669` can never be true because `RestaurantRepository._parseRestaurant` nulls both fields, so free users never see the teaser either. Do not add a `hasInsiderNotes` flag, explicitly rejected. | |
| 3 | Landed. refreshEntitlements now runs on launch and sign-in; unconfirmed claim renders pending, not paid; pending is ephemeral and recomputed. | `b5a2084` |
| 4 | Landed. `seed_data.dart` cut from 57 restaurants to 25, ranks 1 to `kFreeTierMaxRank` only, all 50 insiderTip/whatToOrder pairs removed including on free ranks. Gated content moved to `test/helpers/gated_fixtures.dart`, not deleted. Entitled users on the fallback now get an explicit could-not-load row. Verified by `strings -a` before and after, see "Finding 4" below. | |
| 5 | **Built in three commits, one deployed.** `10cc6ce` event id dedupe plus the ordering guard that stops a retried EXPIRATION downgrading a resubscribed user, **deployed to production 2026-08-17 and verified ACTIVE**. `a594b6d` the `GET /subscribers` reconciliation and the client call behind the pending screen's retry button, **not deployed**: it declares `REVENUECAT_REST_API_KEY`, which does not exist in Secret Manager, and a function declaring a missing secret fails at deploy. `2679757` signature verification, built and held. **Both are switched off by plain constants in `index.ts` (`RECONCILE_ENABLED`, `SIGNATURE_ENABLED`) after the measurement on 2026-08-18 showed a referenced-but-missing secret blocks deploying every function in the codebase, not just its own.** Enabling either is a one line flip in the same commit that creates the secret. Inert until `REVENUECAT_WEBHOOK_SIGNING_SECRET` exists, and `REVENUECAT_SIGNATURE_HEADER` must be confirmed against RevenueCat's documentation before that secret is set. Secret Manager currently holds exactly one secret, `REVENUECAT_WEBHOOK_SECRET`. | `10cc6ce`, `a594b6d`, `2679757` |
| 6 | **Design revised 2026-08-18, still not built:** `docs/FINDING_6_DESIGN.md`. The definition the whole design now rests on: a deletion job is complete not because the cascade ran but because a cascade pass found nothing left to delete. That absorbs the token-revocation race instead of preventing it, and it makes the scheduled resume part of the correctness argument rather than a retry mechanism, so it cannot later be dropped as an optimisation. Concrete consequence: `deleteUserData` returns void today and must return counts, because closure depends on them. Freshness is re-implemented explicitly as an `auth_time` check within five minutes with a distinguishable error code, since a callable inherits none of `requires-recent-login` and without it deletion is available to anyone holding a stolen unexpired token. The rules-flag approach to revocation is recorded as rejected with its reason. One open question left: the job document's identifier and retention. | |
| 7 | Landed. votes rules split into `get` (owner only) and `list: false`. | `1c7639a` |
| 8 | Landed. `submitComment` validated `restaurantId` and `parentId` on trust, and it is the only path that can create a comment, so nothing else was going to check them. Now: the restaurant must exist, and a `parentId` must exist under **that same restaurant** and must itself be top level. The one-level rule is what the read path can express, not a style choice: `getPage` fetches `parentId == null` and `getReplies` fetches `parentId == commentId`, so a reply to a reply would be written and then be permanently invisible to everyone including its author. | |
| 9 | Landed. Cascade guard so applyVoteDeleted/applyCommentDeleted do not throw NOT_FOUND when the parent restaurant is already gone. | `1c7639a` |
| 10 (Fix A) | Landed. Tie-break changed from `name.localeCompare` to `displayOrder` asc, then `id`. Absent displayOrder sorts last. `rank_recompute.ts` now passes the field through, without which the change was inert. | `9f0e512` |
| 10 (Fix B) | **Built through step 5 of 6.** `0c596f8` the zero-vote guard, `3c06e72` the constants, `baselineWeight()`, `baselineFor()`, the wiring into `recomputeAllRanks`, `baselineScore` per restaurant and `cities.baselineWeight` per city, `4f7eaec` the per-run baseline log with its expiry countdown, `0dd0020` the opening-list disclosure on the city screen. Step 6, the teaser projection, is **deferred whole** until Houston's content is real, see "Deferred into Fix B" below. Fix B is complete at step 5 for launch purposes. Design below is unchanged and still accurate. | `0c596f8`, `3c06e72`, `4f7eaec`, `0dd0020` |
| 10 (Fix B, original design note) | **Design written.** Constants decided: `BASELINE_STEP = 2.0`, expiry 20 per restaurant, scaling with `n`. `docs/FIX_B_DESIGN.md`. Baseline derived from `displayOrder`, added as a separate score term, never routed through vote weight. Linear decay to exactly zero at `n * 20` city votes. Absent `displayOrder` gets no baseline. Andrew's zero-vote guard as the outer layer. Carries the deferred teaser projection into the same batch. | |
| 15 | **Landed**, `210c5db`. Three caps as named constants with their reasons in `functions/src/waitlist.ts`: `MAX_WAITLIST_FIELD_CHARS = 100` on `city` and `source`, `MAX_EMAIL_CHARS = 254` (beyond the brief, and needed: `EMAIL_RE` matches a megabyte and the address becomes the document id, so an oversized one used to return a 500 rather than a rejection), and `MAX_SIGNUPS_PER_IP_PER_DAY = 20` in a transaction. Refuses rather than truncates. The allowance is spent after validation, so garbage cannot exhaust the quota of people behind the same carrier NAT. `waitlistIpCounts` denied explicitly in `firestore.rules`, with four rules tests proved to be wired to the rule and not to the default deny. Two things left open, neither of them code in this repo: the Firestore TTL policy on `waitlistIpCounts` has not been run (command in `DECISIONS.md`), and `site/index.html:318` now shows the wrong sentence for a 400 on an oversized city and for a 429. The five old "Waitlist signup logic" tests were deleted, not moved: none of them called `waitlistSignup`, and all five passed with the new validation removed. | `210c5db` |
| 14 | **New, LAUNCH BLOCKING, report delivered, nothing enabled.** App Check is activated but unenforced on every service (`firestore`, `identitytoolkit`, `oauth2`, `places` all `UNENFORCED`, read from the Admin API). So a vote costs an email address rather than a person, and every number in the Fix B manipulation table assumes it costs a person. `firestore.rules` enforcing `weight == 1` protects nothing against a script. See `docs/FINDING_14_APP_CHECK.md`. Hard blocker inside it: `cloud_functions` is not in `pubspec.yaml`, both callables are hand-rolled HTTP POSTs with no `X-Firebase-AppCheck` header, so enforcing them today breaks commenting and suggestions outright. | |
| 13 | **New, not started.** Location data is unusable on the 40 scaffold restaurants, independent of the content question and not fixed by deleting a description. All 40 carry `latitude: 0, longitude: 0`, which is a real point in the Gulf of Guinea, so any map, distance or nearby feature reads all 40 as being in the same place off the coast of Africa. Five carry a non-address in `RestaurantLocation.address`, including `"Various, Chicago, IL"`, which is **displayed to users today** at `restaurant_detail_screen.dart`. Atlanta is clean: 17 of 17 have real Places coordinates. Fix is a Places pass keyed by `placeId`, which Atlanta already has and the scaffold cities do not. | |
| 11 | Landed. Section guard and locked row count both came from `top6to10`, always empty for a free user, so the paywall and the only paid-tier entry point on the screen never rendered. Both now come from rank constants. Locked rows are rank plus a fixed-width redaction bar, no gated field. Six paywall tests rewritten to assert the rule, not the roster. | `2e4efea` |

Other landed work: `39c3edf` voteCount nightly reconciliation plus
docs; `f4c7fa9` profile lockout fix, vote-list backfill script, deploy
order rule; `48df7c3` votedRestaurantIds one-read design; `0dd9416`
UserProfile stops serializing votedRestaurantIds; `74c6bec` project
pinned in every script; `075c322` functions lint back to zero
problems, which is not cosmetic: `npm run lint` is a predeploy step in
`firebase.json` and had been failing since `7a693f2` on one 81
character line, so any `firebase deploy --only functions:...` would
have stopped at the gate before deploying anything.

## Finding 10: measured, not reasoned

Ran `recomputeAllRanks` on the emulator against a faithful Houston
fixture. Actual output.

**Tiebreak.** `functions/src/rank_engine.ts :: assignRanks` sorts by
score desc, then `voteCount` desc, then `a.name.localeCompare(b.name)`.
With zero votes every score and count is 0, so ranking is **purely
alphabetical by name**. Not document order, not undefined.

**Zero votes. Curated in, alphabetical out:**

| Curated (production today) | After one run |
|---|---|
| 1 Mensho | 1 Corkscrew BBQ |
| 2 Tacos Los Brothers | 2 Crave Suya |
| 3 Crave Suya | 3 Joey Uptown |
| 4 The Peri Peri Factory | 4 Lost and Found |
| 5 Corkscrew BBQ | 5 Lotus Seafood |
| 6 Lost and Found | 6 Mensho |
| 7 Top Sushi | 7 Tacos Los Brothers |
| 8 The Better Box | 8 The Better Box |
| 9 Joey Uptown | 9 The Peri Peri Factory |
| 10 Lotus Seafood | 10 Top Sushi |

Mensho falls 1 to 6 with no votes involved.

**One vote on rank 10:** `Lotus Seafood` goes 10 to 1, `score=0.997`,
everything else alphabetical behind it.

**displayOrder.** Appears **nowhere in `functions/src/`**. Used once,
`restaurant_repository.dart:28`, as a client-side secondary sort. In
production it holds **1 to 10 matching rank**, NOT 9999:
`set_houston_launch_order.js` writes `{rank, displayOrder: rank}` and
overwrote what `seed_houston_new.js` had put there. So displayOrder
already carries the curated order faithfully and is a viable stable
tiebreak.

`logCitySummary` already logs `ANOMALY: all N scores identical` and
`ANOMALY: X jumped N positions`. Nobody reads logs at 06:00 UTC.

**Design constraints from the brief, not yet built:** curated order is
a baseline, not a special case; baseline decays to exactly zero at a
named threshold constant; baseline is its own field, never routed
through vote weight or seeded vote documents, because `weight == 1` is
rules-enforced and load bearing for "money cannot buy rank."

## City status: nothing in the app is browsable

**Field.** `status` on `cities/{id}`.

| City | status |
|---|---|
| houston, chicago, la, nyc | **field absent entirely** |
| atlanta | `"comingSoon"` |

`houston` keys: `createdAt, description, id, imageUrl, name,
restaurantCount, state, updatedAt`.

**Client.** `city.dart:17` `@Default(CityStatus.comingSoon)`, so absent
parses as comingSoon. `city.dart:25` `isLive => status == live`.
`home_screen.dart:199` `if (!city.isLive) return _ComingSoonCityCard(...)`
which has **no onTap**.

**What a user sees.** Not an error, not an empty state. Five greyed
non-tappable "Coming Soon" cards. No city detail, no Top 10, no
voting, no comments, no paywall. Looks intentional, entirely inert.

**A publish path now exists.** `scripts/publish_city.js`, logic in
`scripts/lib/city_publisher.js`, 17 tests. One named city, dry run by
default, idempotent (already live is a reported no-op), writes only
`status`, reads back to verify. Every blocking precondition
corresponds to a defect actually found in this remediation:
`displayOrder` present on all restaurants, ranks unique and contiguous
from 1, at least `kFreeTierMaxRank` restaurants, `restaurantCount`
agreeing with reality. Missing images, missing notes and 0,0
coordinates warn rather than block, because those are product
judgements. Original text follows.

**No publish path existed.** Both writers are create-only branches and
houston already exists: `seed_production.js:37` (skips docs with
`createdAt`) and `firestore_writer.js:136` (inside `if (!cityDoc.exists)`).
Both were narrowed by commit `bba62e0` "Seed script cannot publish a
city on create", correct in intent. Publishing is now an undocumented
manual console edit. `firestore.rules` has `cities` `allow write: if false`,
so it cannot be done from the app.

**Zero test coverage.** `grep` for `CityStatus.live` or `isLive` across
`test/` returns nothing.

**Nothing else gates visibility.** `isLive` has exactly two references
in `lib/`. Flipping the one field is genuinely sufficient.

## Finding 11: the paywall is invisible to the users it converts

`restaurant_repository.dart:31` adds
`.where('rank', isLessThanOrEqualTo: 5)` for a free user, so a free
client never receives a document above rank 5.
`city_detail_screen.dart:75` computes `top6to10` from those rows.
`city_detail_screen.dart:133` guards the whole section on
`top6to10.isNotEmpty`. For a free user that list is always empty, so
the Top 10 section and its paywall never render. The paid tier has no
entry point on the city screen.

Same shape as finding 2: the gate hides the pitch from exactly the
users it exists to convert. The six tests passed only because the seed
path loaded gated rows the real query never returns.

**Decision (approved):** render five locked rows where ranks 6 to 10
are, paywall unconditional for free users. Match the marketing site:
rank number, cuisine and neighbourhood visible, name redacted. Build
the rows **from the rank numbers alone**, so no gated field reaches
the client and finding 4's binary claim stays true. **Do not** derive
the count from `cities.restaurantCount`, a known drifting
denormalization. Ranks 6 to 10 is a product constant.

Then rewrite the six tests to assert the rule, not the roster: free
user sees 1 to 5 rendered and 6 to 10 locked, sourced from the
fixture's own ranks, so it survives any reorder.

**Shipped in `2e4efea`.** Two bugs, not one: the section guard at
line 133 and the row count at line 173, which was
`List.generate(top6to10.length, ...)`. Both derived from the same
always-empty list, so fixing only the guard would have rendered a
header above zero rows. Both now come from `kFreeTierMaxRank`,
`kGatedRankStart` and `kGatedRankEnd` in `lib/models/restaurant.dart`.

Rows are rank plus a fixed-width redaction bar. See open decision 6
for why cuisine and neighbourhood are absent.

Red first, with `city_detail_screen.dart` reverted to HEAD and the
constants left in place so the failure was behavioural rather than a
missing symbol: 3 of 5 failed, all free-path, `Found 0 widgets with
text "See plans"`. The entitled-user test passed at HEAD, which
confirms the diagnosis from the other side.

Two of the old assertions named restaurants that had already left the
seed, so their `findsNothing` passed because the string existed
nowhere. `test/helpers/gated_fixtures.dart` restores real production
names as canaries, under `test/` where nothing compiles them into a
release binary. That file is also what finding 4 needs: it is where
gated seed content goes when it leaves `lib/data/seed_data.dart`.

## Finding 4: the verification method that works

Goal: gated data (ranks above 5, and all insiderTip/whatToOrder) stops
being compiled into the release binary; fallback carries ranks 1 to 5
with an explicit could-not-load state.

**The only method that works:**

```
flutter build ios --release --no-codesign
strings -a build/ios/iphoneos/Runner.app/Frameworks/App.framework/App | grep -c "<canary>"
```

**Two methods that produce confident false passes:**

1. `flutter build web --release` then grep `main.dart.js`. Compiles
   fine, but the control string `Mensho` is absent along with every
   other seed string. dart2js does not preserve them greppably.
2. `grep -c` directly on the binary. Returns 0 for everything,
   including controls.

**Always run the before-build grep first and show it finds the
canary.** It killed both bad methods here. A grep returning nothing
after a fix proves nothing unless it returned something before.

Canary must appear only in gated data, not in ranks 1 to 5 and not in
a test file. Always include controls that must **survive**, otherwise
a build that dropped every string would look like a pass.

**Before, at `e3205bd`** (`App`, 7,498,304 bytes):

| Canary | Kind | Count |
|---|---|---|
| `Top Sushi` | rank 7 | 2 |
| `The Better Box` | rank 8 | 2 |
| `Joey Uptown` | rank 9 | 1 |
| `No reservations and lines form. Go off-peak, around 4 PM.` | insiderTip on a **free** rank | 1 |
| `Wagyu Texas BBQ Tantanmen` | whatToOrder | 1 |
| `Mensho` | control, rank 1 | 3 |
| `Corkscrew BBQ` | control, rank 5 | 3 |

**After** (`App`, 7,481,792 bytes, down 16,512):

| Canary | Before | After | |
|---|---|---|---|
| `Joey Uptown` (rank 9) | 1 | **0** | gone |
| `No reservations and lines form. Go off-peak, around 4 PM.` | 1 | **0** | gone |
| `Wagyu Texas BBQ Tantanmen` | 1 | **0** | gone |
| `Top Sushi` (rank 7) | 2 | **1** | seed copy gone, `demo_image_overrides.dart` copy remains |
| `The Better Box` (rank 8) | 2 | **1** | same |
| `Mensho` (rank 1, control) | 3 | 3 | survives, as required |
| `Corkscrew BBQ` (rank 5, control) | 3 | 3 | survives, as required |

The controls holding at 3 is what makes the zeros mean something. A
build that dropped every string would show the same zeros.

**Why it was reverted the first time:** stripping gated rows made six
paywall tests fail, which exposed finding 11. That is now closed
(`2e4efea`), which unblocked this.

### Landed

`lib/data/seed_data.dart` went from 57 restaurants to 25: ranks 1 to
`kFreeTierMaxRank` only, and all 50 `insiderTip` / `whatToOrder` pairs
removed. Note that insider notes were stripped from **free** ranks
too. They are a `cityInsider` entitlement regardless of rank, so rank
alone was never the right filter.

Gated content moved to `test/helpers/gated_fixtures.dart` rather than
being deleted. Deleting it would have made three `findsNothing`
assertions pass because their strings existed nowhere.

Three tests broke on the change, all of them tests that had been
relying on `hou-1` carrying notes from the seed. They now take an
`AppState` built on `buildGatedFixtureAppState(withInsiderNotes:
true)`. `test/screens/restaurant_detail_screen_test.dart` had its own
local `buildTestApp` with a different signature, so it needed its own
`appStateOverride` seam.

### A second channel, found by the after-grep, NOT fixed

`lib/config/demo_image_overrides.dart` maps restaurant name to a
bundled asset path, and `assets/demo/` is declared in `pubspec.yaml`
line 63, so it ships. Three of its 29 keys are gated restaurant names:

| Key | Rank |
|---|---|
| `lost and found` | 6 |
| `top sushi` | 7 |
| `the better box` | 8 |

The matching files exist: `assets/demo/Lost and Found.png`,
`Lost and Found 2.png`, `Top Sushi.png`, `The Better Box.png`. So the
names and the photographs of three gated restaurants ship in the
release bundle regardless of what `seed_data.dart` holds. Emptying the
seed does not close this.

**Deliberately not fixed here.** The file opens with "DEMO ONLY. Set
false or delete before any public launch build" and carries its own
removal checklist, so flipping `kUseDemoImageOverrides` is a launch
decision with visible consequences for every demo build, not a
cleanup to fold into this commit. It is also entangled with open
decision 4, image hosting.

**Consequence for the numbers below:** `Top Sushi` and `The Better
Box` do not reach zero after this change, and the reason is this file,
not the seed. `Joey Uptown` (rank 9) is the uncontaminated rank
canary.

**Explicit could-not-load state.** The gap was an entitled user on the
fallback: `top6to10` is empty, so the whole section used to vanish and
five restaurants read as "this city has five restaurants". Now
`_GatedLoadFailed` renders "Couldn't load ranks 6 to 10". Deliberately
not styled as a locked row, because that content is missing rather
than withheld and they already paid for it. Tested via
`UnreachableRestaurantRepository`, which throws from `getForCity` so
`AppState` takes the real catch branch and sets `isOffline`.

## Insider notes: provenance traced, 33 deleted

All 50 notes documents in production were traced before anything was
wired. Two sources, neither of them Andrew.

**33 deleted** (houston 3, chicago 10, la 10, nyc 10). Origin: one
hardcoded object at `scripts/seed_production.js:91`, introduced by
`162b12b` (2026-05-07), a commit whose own message calls it scaffold.

Generated, not observed, and one case proves it rather than arguing
it: `hou-4`'s tip "The patio with the downtown skyline view is the
spot" paraphrases the description three lines above it in the same
file, "a downtown-view patio". Text derived from adjacent text.

This corrected the brief. It had said the wiring could ship against
"Houston's three real notes only". Houston's three come from the same
object, same file, same commit as the other thirty, so they were not
real either.

Deleted via `scripts/delete_seeded_insider_notes.js` (dry run by
default, cities named explicitly, aborts rather than guessing on an
unrecognised city, reads back after deleting). The hardcoded object in
`seed_production.js` was emptied in the same commit, because line 206
rewrites it and a later `--force --confirm` run would have restored
all 33.

**17 held**, all Atlanta, different provenance. See below.

### Atlanta's 17: salvageable, held pending Andrew

Source is `data/atlanta_candidates_seedready.csv`, committed by
`2b5da37` (2026-07-03) and described there as a "curated candidate
list". `docs/DECISIONS.md` (2026-05-09) records the pipeline:
"Curated via TikTok food creator candidates + Reddit + Eater +
Michelin pipeline. **Andrew sources Top 10 candidates per city.**"

Four independent signals that this is human-sourced, not generated:

1. **Dish specificity.** "Tortelli di Mele (round ravioli filled with
   Granny Smith apple, sausage, and parmigiano, topped with browned
   butter and sage)". "Caviar and Middlins". "Honey hot wings (ask for
   the sauce on the fries too)". Ingredient level and ordering hacks,
   not listicle summary.
2. **Gaps.** Row 14, The Dining Experience, has an empty
   `WhatToOrder`. Generated sets do not have holes.
3. **The selection.** Juci Jerk in Stone Mountain, Jamaican Jerk Biz
   in Mableton, The Dining Experience in Fairburn, Clay's in Sandy
   Springs. Suburban neighbourhood spots. A generative pass on "best
   Atlanta restaurants" returns Bacchanalia, Staplehouse, Gunshow. The
   scaffold cities' picks are exactly that canonical shape: Peter
   Luger, Katz's, Alinea, Bestia.
4. **The field split**, which is binary and decisive.

| City | docs | description | vibeTags | openingHours | placeId |
|---|---|---|---|---|---|
| atlanta | 17 | **0** | **0** | **17** | **17** |
| chicago | 10 | 10 | 10 | 0 | 0 |
| houston | 10 | 10 | 10 | 0 | 0 |
| la | 10 | 10 | 10 | 0 | 0 |
| nyc | 10 | 10 | 10 | 0 | 0 |

Atlanta has zero narrative fields and full Google Places enrichment.
The other four have full narrative and zero external verification.
That is the provenance line drawn by the data itself.

Atlanta's notes are still not "Andrew went there", so they need
honest attribution rather than the insider-note voice.

## Content provenance audit

`docs/CONTENT_PROVENANCE_AUDIT.md`, 2026-08-13. Every user-visible
field written by the two seed scripts, traced and checked for whether
it asserts something about the real world.

Four confirmed falsehoods live in production, the worst being
`nyc-2`'s description telling users that Dom DeMarco, who died on
17 March 2022, is hand-cutting basil onto their pizza. Seven more need
verification, including a possible fabricated Michelin star on
`Corkscrew BBQ`, a Houston launch restaurant.

The provenance line is binary on every field. Atlanta: 0 descriptions,
0 vibeTags, 17 Places-verified addresses with real coordinates.
Scaffold cities: 40 descriptions, 40 sets of vibeTags, 0 placeIds,
and all 40 coordinates set to `0,0`.

## Reachability sweep

`docs/REACHABILITY_SWEEP.md`, 2026-08-13. Every conditional render
path and gated read in `lib/`, answered against production rather than
against a fixture. Findings 2, 11 and 12 turned out to be five
instances of one defect, and the sweep found the fifth
(`getInsiderNotes` has zero call sites in `lib/` while 50 of 57
restaurants hold the subcollection it reads).

## Deferred into Fix B: the public teaser projection

Locked rows ship as rank only. The teaser (rank, cuisine,
neighbourhood, name hidden) is worth building and is **not** blocked
on secrecy: vouchfood.com already publishes exactly that pairing for
ranks 6 to 10 on the open web with no paywall, so the projection
reveals nothing new.

It is deferred because of where it must live. A separate job writing
it would be a fourth drifting denormalization, alongside
`cities.restaurantCount` and comment `userName`. The correct shape is
one publicly readable teaser document per city holding
`{rank, cuisine, neighbourhood}` for the gated band, written by
`recomputeAllRanks` **inside the same batch that sets rank**, so it is
in sync by construction rather than by a job that can fall behind.

That batch is only open during Fix B. Build it there, not on its own.

### Blocked, found 2026-08-16 while building it

**There is no neighbourhood anywhere in the data.** `Restaurant` has
`cuisine` but no neighbourhood field, and the nearest candidate,
`RestaurantLocation.name`, is not one. In Houston's seed it holds
`Chinatown` and `South Main`, which are neighbourhoods, alongside
`Richmond Ave` and `Westheimer`, which are streets, and `Spring`,
which is a separate city. Publishing that column as "neighbourhood"
would publish three different kinds of thing under one label, and it
would do it on the public, unauthenticated read surface where it is
the first thing a prospective subscriber sees.

So the projection cannot be built as specified. Two calls, both
Andrew's:

1. **Where neighbourhood comes from.** A new field backfilled per
   restaurant (Atlanta's 17 have `placeId` and could be filled from
   Places, the scaffold cities cannot, see finding 13), or the teaser
   ships as `{rank, cuisine}` only and the column is dropped.
2. **Whether the locked row changes at all.** Today it is rank plus a
   fixed-width redaction bar (`_LockedRestaurantPlaceholder`,
   finding 11). Showing cuisine and neighbourhood there is a paywall
   conversion decision, not a data one, and the write path is worth
   nothing until it is made.

The write half could ship ahead of the read half, since the argument
for building it inside the rank batch holds either way. It has not,
because a public collection written for a consumer that may never
exist is the same shape of unread work this remediation keeps
finding.

## The open list: climbable, and unreachable

Measured 2026-08-18, `docs/OPEN_LIST_MEASUREMENT.md`, with
`functions/src/open_list.test.ts` pinning the numbers.

**The climb works.** Running the real engine, a newcomer with no
`displayOrder` in a launch city needs **4 votes to reach rank 10 and
20 to reach rank 1**. FIX_B_DESIGN's "17 net votes from last to
first" describes a curated rank 10, which carries its own baseline
and does not enlarge the city; a newcomer needs 20. Not decorative.

**Nothing can arrive.** `submitSuggestion` writes to `suggestions`
with `status: "pending"` and nothing reads that collection except the
account-deletion cascade. Every restaurant-writing script writes a
whole city roster; there is no script that adds one restaurant to a
live city. So the open list is a property of the ranking engine and
not a feature of the product, which is the same shape as findings 2
and 11.

**A trap for when it becomes real.** `backfill_display_order.js` sets
`displayOrder = rank` on every document lacking it. A newcomer's
absent `displayOrder` is deliberate, not a gap, so one run of that
script would grant it a curated baseline at whatever rank it had
climbed to, silently. The script is not wrong; its precondition
expired.

**A property nobody had stated.** Each newcomer raises every
incumbent's baseline, because position value scales with `n` and the
expiry does too. Curated first place gains 11 percent of its
protection when an 11th restaurant appears; curated last place
doubles its own, 1.8 to 3.636. Small at one newcomer, and it
compounds.

## `RestaurantLocation.name`: where it renders today, and what it claims

Asked after the teaser finding: if that field holds three kinds of
thing, is the mislabel already live somewhere nobody looked. Read
only, nothing changed.

**One renderer, and it is reachable by everybody.**
`restaurant_detail_screen.dart:412` renders a section headed
`Locations`, then one `LocationCard` per entry.
`location_card.dart:34` puts `location.name` as the bold first line
beside a map-pin icon, with `location.address` in caption type
directly beneath it. Nothing else displays it: not `RestaurantCard`,
not the city screen, not the home screen. The section sits on the
detail screen for ranks 1 to `kFreeTierMaxRank`, so a signed-out free
user sees it.

**The values, from the scripts that wrote production.**

| Kind | Houston values |
|---|---|
| Neighbourhood or district | `Chinatown`, `Midtown`, `Galleria / Uptown` |
| Street or freeway | `Richmond Ave`, `Westheimer`, `Southwest Freeway`, `South Main` |
| Area outside the city | `Cypress Creek` |
| A different municipality | `Spring` |

Scaffold cities additionally carry `Multiple locations` paired with
the address `Various, New York, NY`, which is finding 13's non-address
problem in the same widget.

**Provenance confirms the ambiguity was upstream of the code.**
`seed_atlanta.js:350` sets `name: candidate.area || "Atlanta"`, read
from a CSV column titled `Area`
(`data/atlanta_candidates_seedready.csv`). Houston's equivalent column
is titled `Area / City` in
`data/houston_candidates_seedready.csv`, which says it out loud, and
that file is header-only with zero rows, so Houston's values were
hardcoded in `seed_production.js` instead.

**The answer: the strong mislabel is not live.** Three things hold it
back, and all three are absent on the teaser surface, which is why the
same field was refusable there and tolerable here.

1. **The heading is `Locations`, not `Neighborhood`.** It is generic
   enough to be true of a neighbourhood, a street and a suburb alike.
   Nothing on the screen claims the value is a neighbourhood.
2. **The address sits directly under every value**, so each card
   corrects itself. A reader who sees `Spring` also sees
   `26608 Keith St, Spring, TX 77373`.
3. **One restaurant is on screen at a time.** The values never form a
   column under one heading, which is exactly what a teaser would have
   done, and a column is what turns an inconsistent field into a
   category claim.

**What is live is the weak version**, and it is worth knowing rather
than fixing: a field with three meanings rendered as though it had
one, bounded by the address beneath it. The two cases that actually
misinform are `Spring`, which reads as a Houston area until you read
the address, and Atlanta's `|| "Atlanta"` fallback, which would print
the city's own name as a branch label and say nothing at all. Atlanta
is not shipping.

**Consequence for the `neighborhood` field when it lands.** Render it
as its own thing. Do not retrofit meaning onto `location.name`, and do
not relabel the `Locations` section: the generic heading is currently
the only reason the existing values are not a lie.

## Image pipeline: a deadlock, and therefore a hard blocker

Four facts that do not fit together:

1. Photographs render only through the demo layer
   (`RestaurantImage.build()` checks `resolveDemoAsset` first).
2. The demo layer is marked for deletion before any public build.
3. Deleting it costs 6 images, not 27. **Corrected by the sweep:** only
   6 of the 29 demo keys match a real restaurant name, so 21 of the 27
   curated documents already render a grey placeholder today. See
   `docs/REACHABILITY_SWEEP.md`.
4. The demo layer ships gated restaurant names and photographs into
   the binary regardless of what the seed holds (see finding 4).

So it cannot ship, cannot be deleted, and is the only thing making
photographs work. One exit: **Firebase Storage.** Cheaper than it
looks, since `assets/demo/` already holds 59 photographs. This is an
upload script and a field write.

Four constraints, agreed:

- **Key by restaurant id, not name.** `resolveDemoAsset` matches on
  lowercased name, the same fragility as `LAUNCH_ORDER` matching exact
  name strings. Both miss silently on ChòpnBlọk's diacritics and on
  `Corkscrew` versus `CorkScrew`. A lookup that fails by returning
  nothing, where nothing is a valid state, never reports itself.
- **Delete the demo layer in the same commit.** Not deprecate, not
  flip the flag: `demo_image_overrides.dart`, `assets/demo/`, and
  `pubspec.yaml:63`. Half a migration leaves two lookup paths and the
  leak stays.
- **Re-run the after-grep.** `Top Sushi` and `The Better Box` should
  reach zero and the controls should hold. That takes finding 4 from
  5 of 7 canaries to 7 of 7.
- **Do not migrate the 30 Unsplash rows.** Stock photographs standing
  in for specific real restaurants' food, in cities that are not live.
  Delete the URLs.

Plan goes to Andrew before it runs, including what `RestaurantImage`
becomes and its loading and failure states.

**Written 2026-08-16: `docs/STORAGE_MIGRATION_PLAN.md`.** Nothing in
it has been run. Two things it turned up that were not in the record
here. The photographs' provenance is written down nowhere, and the
migration changes what is being claimed about them (a file bundled in
a private demo build is a small exposure; the same file served from
the project's own bucket beside a paywall is publishing), so that
question blocks step 0. And `assets/demo/` is **175 MB of PNGs**,
averaging 3 MB each at about 1600px, so re-encoding is part of the
migration rather than a nicety: measured at quality 80, `Mensho.png`
goes 5,100 KB to 840 KB at hero size and 288 KB at card size.

## Image pipeline

`RestaurantImage.build()` checks `resolveDemoAsset(restaurant.name)`
**first**. `demo_image_overrides.dart:10` has
`kUseDemoImageOverrides = true`, and `assets/demo/` holds **59 bundled
PNGs** mapped by lowercased name. A match renders `Image.asset`. Only
on no match does it fall through to `CachedNetworkImage(imageUrl)`.
There is **no Firebase Storage integration**. Failure states: grey
`Container` while loading, grey container with icon on network error.

`imageUrl` across all 57 restaurants: **27 `placeholder://restaurant`**
(all of Houston and Atlanta) and **30 `images.unsplash.com`** (all of
Chicago, LA, NYC). Not 57 placeholder.

**The trap:** `docs/DECISIONS.md` (2026-06-08) carries a PRE-LAUNCH
CHECKLIST requiring `kUseDemoImageOverrides` be set false or the file
deleted, plus `assets/demo/` and the pubspec entry, before any public
store build. Doing that turns every Houston and Atlanta card into a
grey box, because those fall through to `placeholder://restaurant`
which is not a URL.

**Decisions pending:** delete the 30 Unsplash URLs (approved in
principle, not done). Choose bundled assets versus Firebase Storage;
Storage recommended because the open list means restaurants added
after release have no bundled asset. Cost writeup not yet produced.

`assets/demo/ChopnBlok.png` exists while ChòpnBlọk exists in no city.
The photograph for the planned new rank 1 is already in hand.

## Verified true, contrary to the stale gates document

`VOUCH_APP_STORE_GATES.md` (not present in this repo) is out of date.
Both App Review claims verify:

- `containsBannedContent(text)` at `functions/src/index.ts:247` runs
  before `commentRef.set(...)` at 277, and a rejection throws, so a
  filtered comment is never stored.
- `firestore.rules` comments block: `allow create: if false`.

## Open decisions waiting on Andrew

1. **Finding 2 insider notes.** 3 of the free-visible five lack notes:
   `hou-11` Tacos Los Brothers (rank 2), `hou-12` Crave Suya (3),
   `hou-13` The Peri Peri Factory (4). May be resolved by the reorder
   below instead of by writing notes.
2. **The new Houston top five.** ChòpnBlọk (1), Mensho (2), CorkScrew
   BBQ (3), Roostar (4), JOEY Uptown (5). **ChòpnBlọk and Roostar do
   not exist** in Firestore or `seed_data.dart`, verified across all
   57 documents in every city with loose matching. Two new documents
   needed, not a rank swap. Addresses given: ChòpnBlọk, 507 Westheimer
   Rd, Houston, TX 77006, West African, Montrose. Roostar Vietnamese
   Grill, 2929 Navigation Blvd, Houston, TX 77003, Vietnamese, East
   End, multi-tenant retail centre so a suite may be needed. Andrew is
   writing the insider notes; **do not write any of them.** Promoting
   two in pushes two out of the ten; that departure needs to be a
   visible side-by-side decision. Lost and Found (rank 6) already has
   notes.
3. **Collapse the launch order to one source.** It currently lives in
   `set_houston_launch_order.js`, `seed_production.js`,
   `seed_houston_new.js` and `seed_data.dart`. `LAUNCH_ORDER` matches
   by exact name string and will silently no-op on ChòpnBlọk's
   diacritics and on `Corkscrew` versus `CorkScrew` casing. Worth its
   own test.
4. **Image hosting**, bundled versus Storage.
5. **Setting Houston live.** Finding 11 has now shipped (`2e4efea`),
   so the paid tier has an entry point when it does.
6. **What a locked row shows.** The brief asked for both "rendered
   from the rank numbers alone, no gated field reaches the client in
   any form" and "rank, cuisine and neighbourhood visible and the
   name redacted." These conflict: `restaurant_repository.dart:31`
   filters ranks above `kFreeTierMaxRank` out of the query and
   `firestore.rules` denies them independently, so the free client
   holds no document for ranks 6 to 10 and there is no cuisine or
   neighbourhood to redact. Shipped as rank only, because that is the
   reading that keeps finding 4's binary claim checkable. Showing
   real cuisine and neighbourhood needs a publicly readable teaser
   projection: new fields, new rules, and a different shape of
   verification for finding 4.

## Required fields for a new restaurant document

Required by `lib/models/restaurant.dart`, will not parse without:
`id, cityId, name, cuisine, imageUrl, description, rank`. A complete
production doc also carries `displayOrder, priceLevel, locations`
(name plus address), `vibeTags, voteCount, rankScore, createdAt,
updatedAt`. Optional subdocument `insiderNotes/notes` with
`restaurantId, whatToOrder, insiderTip`.

## Framework additions still not landed

At `Desktop/_framework/AI_BUILD_FRAMEWORK.md` (not directly on the
Desktop):

- **3e**: a citation proves a thing exists, not that it is reachable.
- **14**: test the composition root.
- **15**: carry the scope qualifier when restating someone else's
  measurement.

Also requested: add the finding 4 before-grep story to
`docs/IMPLEMENTATION_RATIONALE.md` as a worked example.
