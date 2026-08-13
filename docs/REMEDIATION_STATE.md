# Remediation state, 2026-08-13

Handover for an instance with no memory of this cycle. Specifics over
prose. Everything here was measured against code or production unless
it says otherwise.

## URGENT: a scheduled job is paused and must not be restored yet

`recomputeRanks` was **deleted from production** on 2026-08-13, before
its 06:00 UTC fire, via:

```
firebase functions:delete recomputeRanks --project majorcitymusteats --force
```

Source is untouched (`functions/src/index.ts:317`). Restore is a
redeploy, no code change:

```
firebase deploy --only functions:recomputeRanks --project majorcitymusteats
```

**Do not restore until finding 10's fix ships.** Running it against
current production destroys Houston's curated order (see finding 10).
The other 10 functions are deployed and untouched.

Side effect, accepted deliberately: this also pauses the `voteCount`
drift correction. 33 of 57 restaurants hold negative `voteCount` with
zero vote documents. Invisible, because nothing in the app is
browsable (see city status). The first run after finding 10 lands
clears it.

## Findings

| # | Status | Commit |
|---|---|---|
| 1 | Landed. VoteRepository never wired into AppState in main.dart, so votes never reached Firestore. Composition-root test added. | `57e7695` |
| 1 (failure path) | Landed. toggleVote awaits and rolls back; rules split get/list; cascade guard on applyVoteDeleted/applyCommentDeleted. | `1c7639a` |
| 2 | **Blocked on Andrew.** insiderNotes never load, and the outer gate at `restaurant_detail_screen.dart:669` can never be true because `RestaurantRepository._parseRestaurant` nulls both fields, so free users never see the teaser either. Do not add a `hasInsiderNotes` flag, explicitly rejected. | |
| 3 | Landed. refreshEntitlements now runs on launch and sign-in; unconfirmed claim renders pending, not paid; pending is ephemeral and recomputed. | `b5a2084` |
| 4 | **In flight, reverted, unblocked by the finding 11 decision.** See "Finding 4" below. | |
| 5 | Not started. Prepare signature verification, GET /subscribers reconciliation, event-id dedupe against a test secret. Andrew is generating `REVENUECAT_WEBHOOK_SIGNING_SECRET`, kept separate from the existing bearer secret. | |
| 6 | Not started. Account deletion is not resumable. Comments anonymisation already removes the uid (`user_cleanup.ts:130` writes `userId: "deleted"`), so that decision is NOT re-opened. Record in DECISIONS.md that deletion works on the happy path and does not survive interruption. | |
| 7 | Landed. votes rules split into `get` (owner only) and `list: false`. | `1c7639a` |
| 8 | Not started. `submitComment` target validation. The client cannot write comments at all, so this applies to that callable only. | |
| 9 | Landed. Cascade guard so applyVoteDeleted/applyCommentDeleted do not throw NOT_FOUND when the parent restaurant is already gone. | `1c7639a` |
| 10 | **Measured, design not written. Outranks everything except city status and 11.** | |
| 11 | Landed. Section guard and locked row count both came from `top6to10`, always empty for a free user, so the paywall and the only paid-tier entry point on the screen never rendered. Both now come from rank constants. Locked rows are rank plus a fixed-width redaction bar, no gated field. Six paywall tests rewritten to assert the rule, not the roster. | `2e4efea` |

Other landed work: `39c3edf` voteCount nightly reconciliation plus
docs; `f4c7fa9` profile lockout fix, vote-list backfill script, deploy
order rule; `48df7c3` votedRestaurantIds one-read design; `0dd9416`
UserProfile stops serializing votedRestaurantIds; `74c6bec` project
pinned in every script.

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

**No publish path exists.** Both writers are create-only branches and
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

**Before-state measured** (`App`, 7,498,304 bytes): canary
`patio with the downtown skyline view` = 1, `The Better Box` = 2,
`Tantanmen` = 1, control `Mensho` = 3.

Canary must appear only in gated data, not in ranks 1 to 5 and not in
a test file.

**Why it was reverted:** stripping gated rows made six paywall tests
fail, which exposed finding 11. Blocked on that decision, now given.
Working tree was reverted clean; the seed transformation is a short
scripted edit to redo.

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
