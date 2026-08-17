# Engineering review: everything since the Codex review

Scope: `fb70969~1..HEAD`, **52 commits**, 2026-08-12 to 2026-08-18,
**108 files, +13,334 / -1,598** excluding `site/`. Written for a
reviewer who has the diff but not the history.

Same contract as `docs/IMPLEMENTATION_RATIONALE.md`, which this
extends rather than repeats: an entry earns its place only if the
reasoning cannot be recovered from the code. Each one answers the
four questions that document asks of any claim.

1. **What is being claimed?**
2. **Why does the claim need a method at all?**
3. **What method establishes it, and what does it cost?**
4. **What produces a confident false pass, and what rule catches it?**

Two entries are already written up there and are not repeated:
verifying that gated data is not in the release binary, and why a
seam that depends on how many test files are running is not a seam.

## What this cycle was actually about

Almost nothing here is a feature. The Codex review found bugs; the
work that followed found something narrower and worse. **Most defects
were not code that was wrong. They were code that was correct and
unreachable, tested by tests that could not fail, describing data that
was not true.**

Every entry below is a variation on one question: does this work for a
real user, on real production data, and does what it says match what
is happening?

---

## 1. A branch guarded on data the production read path cannot supply

**The claim.** A conditional render works because its condition is
correct and its tests pass.

**Why it needs a method.** Both of those can be true while the branch
is dead. The condition is evaluated against data the test loads
through a path the real app never uses, so the test proves the branch
renders when the data is there, and says nothing about whether the
data can ever be there.

The sweep's own summary: rows A, B, C, D and finding 11's
`List.generate(top6to10.length, ...)` are **one defect in five
places**. The ones worth carrying forward:

| Row | Where | The condition | Why it could not be true, or was always true |
|---|---|---|---|
| A | Insider notes gate, `restaurant_detail_screen.dart:669` | `whatToOrder != null \|\| insiderTip != null` | `RestaurantRepository._parseRestaurant` nulls both on every parse |
| B | `getInsiderNotes` | n/a, it is a method | **Zero call sites in `lib/`** for three months, while its data, reader and widget all existed |
| D | `home_screen.dart:199` (finding 12) | `!city.isLive` | **Always true, for everyone.** `status` is absent on 4 cities and `city.dart:17` defaults absent to `comingSoon`, so the tappable-city branch was unreachable |
| 11 | Top 10 section guard and locked row count | `top6to10.isNotEmpty`, `List.generate(top6to10.length, ...)` | A free user is never sent a document above rank 5, by query and by rules, so the list is always empty |
| O | Demo image resolution | name matches a key | 23 of 29 keys match no restaurant in production |

The paywall case is the one that cost money: **the section guard and
the row count both derived from a list that is empty for exactly the
users the paywall exists to convert.** The paid tier had no entry
point on that screen at all. Row D is the one that shows the class
most clearly: not a branch that never fires, but its opposite,
permanently stuck on and rendering "coming soon" over a live city.

**The method.** Answer reachability against production, not against
the repo. `docs/REACHABILITY_SWEEP.md` reads every gated branch in
`lib/` and asks "can this be true for a real user, and which user",
citing one of three sources per row: **prod** (Admin SDK read of
`majorcitymusteats`), **code** (traced from call site to writer), or
**rules**. Nothing was fixed during the sweep. Measurement only, so
that the fixes could be argued from a fixed record.

**The false pass.** A widget test that builds the fixture itself.
Every one of these branches had passing tests.

**The rule.** Standing rule 3e: *a path existing is not a path being
reachable.* When a branch is guarded on loaded data, name the writer
of that data before believing the branch. If the writer is a test, the
branch is dead.

**How the fixes were shaped by it.** Locked rows are now rendered from
the rank constants (`kGatedRankStart`, `kGatedRankEnd`), not from
loaded data, because the constants are the only source that exists for
a free user. That is also what keeps gated fields out of the client.

---

## 2. The composition root is a thing under test

**The claim.** `VoteRepository` works, so votes reach Firestore.

**Why it needs a method.** The repository did work. Its unit tests
passed. `main.dart` never passed it to `AppState`, so
`toggleVote`'s `if (_useFirebase && _voteRepo != null)` guard was
false in production forever: votes updated local state and
SharedPreferences and never reached the database. **Every existing
test passed, because none of them went through `VouchApp.build()`.**

**The method.** `test/composition_root_test.dart` pumps the real
`VouchApp` widget, with only the leaf Firestore instance substituted
for a fake, and asserts that a vote cast through the real tree lands
in Firestore. The seam is a single `firestoreOverride` parameter that
`main()` never passes.

**The false pass.** Any test that constructs the object graph itself.
It proves the wiring the test wrote, not the wiring the app ships.

**The rule.** Rule 14: *test the composition root.* If a dependency is
optional and its absence degrades silently, the graph that ships must
be exercised by something.

**Applied again this cycle.** `MembershipProvider` now constructs
`MembershipRepository` on demand when none is injected, rather than
treating null as "skip reconciliation". `main()` builds that provider
before `VouchApp` exists, so no composition-root test could have
caught a missing wire there. Removing the possibility beat testing
for it.

---

## 3. Ranking integrity: the two fixes, and how each could have been faked

**The claim.** "Locals decide" and "money cannot buy rank."

**Why it needs a method.** Both are enforced by arithmetic nobody
looks at, on data that barely exists yet. Run against real Houston
data, the pre-fix engine moved Mensho from rank 1 to rank 6 **with
nobody voting**, because the final tie-break was `name.localeCompare`
and every score was zero.

**Fix A**, tie-break on `displayOrder` then `id`. The subtlety worth
recording: the change to `rank_engine.ts` was inert on its own, since
`rank_recompute.ts` did not pass the field through. A test of the
engine alone would have passed against a fix that did nothing.

**Fix B**, a curated baseline that decays to exactly zero. Three
properties, each with a method:

| Property | Method | What would have faked it |
|---|---|---|
| Baseline follows `displayOrder`, never live `rank` | A fixture where the two **disagree**, asserted at the wiring | `expect(baselineFor.length).toBe(3)`. Arity proves nothing: a caller can still pass `rank` in the `displayOrder` slot, which is the actual failure mode |
| The weight never rises | A property test over 1,000 vote counts | Inheriting it from "votes only grow", which is true two layers away and nobody asserts |
| The log describes the run that happened | Assert the logged weight against the value **written to the city document**, not against a literal | A literal, which drifts from the code the day the constant changes |

**The false pass that actually occurred.** The red proof for the
`displayOrder` wiring was re-run rather than inherited from the
previous session's transcript, and the inherited claim was wrong: the
sabotage fails **4** tests, not 2. A number carried forward from a
transcript is a number nobody measured.

**The rule.** Rule 15: *carry the scope qualifier, or re-measure.* And
its corollary here: assert the wiring, never the signature.

**Money cannot buy rank, kept true structurally.** The baseline is an
additive term at rank time. It is never a vote and never a vote
weight, so `firestore.rules:82` (`weight == 1` on every vote write,
with the denial pinned by the rules suite) keeps meaning what it says.

---

## 4. Tests that could not fail

**The claim.** `waitlistSignup` was tested. Five tests said so.

**Why it needs a method.** All five built their own document ids,
wrote their own documents, and asserted that Firestore had stored what
the test wrote. The honeypot case simulated the handler with an
`if (!website)` **inside the test body**. They were checking that
Firestore is Firestore.

**The method that settles it.** Delete the production validation and
run them. All five still passed against an endpoint with no size caps
and no rate limit. That measurement, not the reading, is what
justified deleting them.

**What replaced them.** `waitlist.test.ts` calls
`waitlistSignup(req, res)` itself, with a recording response. Same for
`submitComment`, which is called through `submitComment.run()` rather
than reimplemented.

**The rule, in one line.** *If the test would pass with the production
code deleted, it is not a test.* Delete rather than repair, and record
what it was, because a repaired reimplementation still tests the
reimplementation.

**The related trap, already in `DECISIONS.md` (2026-06-09).** A
`findsNothing` assertion against a string that exists nowhere passes
for the wrong reason. Two paywall tests were caught asserting against
restaurant names absent from the seed. The fix was not to delete the
canaries but to **move them** to `test/helpers/gated_fixtures.dart`,
so the assertion proves the gate held rather than proving a string was
garbage-collected.

---

## 5. Money: not knowing is not the same as knowing there is nothing

**The claim.** A subscriber's tier is correct.

**Why it needs a method.** The RevenueCat webhook is the only writer
of the `membershipTier` claim, and `firestore.rules` gates on that
claim alone. Every failure mode is silent from inside the app.

**Three defects, three methods** (finding 5, commits `10cc6ce`,
`a594b6d`, `2679757`):

**Ordering, not just duplication.** Deduplication by event id was the
smaller half and is honest about it: both writes were already
idempotent. The defect worth fixing needs two *different* events:

```
t=1000  EXPIRATION   fails, RevenueCat will retry
t=2000  PURCHASE     arrives, applied, user is localsPass
t=1000  EXPIRATION   the retry, arriving late
```

The third line set a paying user back to free, permanently, because
the client's pending state can only be cleared by the webhook that
never came. A per-user watermark now refuses an event older than the
newest applied. **The control is asserted next to the case**: a
*newer* EXPIRATION still downgrades, or the guard would be
catastrophically wrong in the other direction.

**A failed lookup must never read as "no entitlements".** The
reconciliation calls RevenueCat's REST API, and every uncertain path
throws rather than returning an empty list: an empty list is a real
answer meaning "this person pays for nothing", and a parse failure
must not be able to impersonate it. 404 is the single non-200 treated
as an answer. A grace period counts as active, because that is exactly
the window where a card is being retried.

**The endpoint refuses rather than pretends when disabled.** With its
switch off it throws `failed-precondition`; answering "free" would
downgrade every caller.

**The false pass.** A test suite that only covers the happy path, and
a signature test that proves nothing: the first version of the
raw-body test used key order, and V8 preserves insertion order for
string keys, so the "different" bytes were identical and the
assertion passed for the wrong reason. Corrected to whitespace and an
escaped character, with the correction recorded in the test.

**The rule.** *Distinguish "we could not check" from "there is
nothing".* They look alike in a return value and produce opposite
actions.

---

## 6. Public write surfaces: caps that refuse, and constants that argue

**The claim.** `waitlistSignup` is safe because it deduplicates.

**Why it needs a method.** The dedup is real and structural (the
document id **is** the normalised email), which makes the obvious
flood attack useless and hides the real one: unique addresses were
unbounded, and each row could be inflated toward Firestore's 1 MiB
limit. Write cost is one time. **Storage cost is recurring**, and
recurring is the damage.

**The method.** Three named constants, each carrying the reason a
future reader would need to widen it responsibly
(`functions/src/waitlist.ts`):

| Constant | Value | Why that number |
|---|---|---|
| `MAX_WAITLIST_FIELD_CHARS` | 100 | Longest real answer, "Winston-Salem, North Carolina", is 29. Past 100 it is a payload |
| `MAX_EMAIL_CHARS` | 254 | RFC 5321. `EMAIL_RE` is `[^\s@]+@[^\s@]+\.[^\s@]+`, and "not a space and not an at sign" matches a megabyte |
| `MAX_SIGNUPS_PER_IP_PER_DAY` | 20 | Carrier NAT puts real people behind one address; a refused genuine signup is unrecoverable, 20 rows a day is not |

`MAX_EMAIL_CHARS` was beyond the brief and is the one worth keeping:
the address becomes the document id, Firestore caps ids at 1500 bytes,
so the pre-fix failure was **a 500 for what is plainly a bad
request**. Three layers deep, none of them in the original finding.

**Design rules that fell out.**

- **Refuse, do not truncate.** A truncated city is a wrong answer
  stored as though it were right, in a field a human typed.
- **Spend the rate-limit allowance after validation**, so a stream of
  garbage cannot exhaust the quota of the humans behind the same
  address. Asserted, not assumed.
- **Fail closed on an unknown IP**, into one shared bucket, with a
  test that says so, because the alternative is an unbounded public
  write path if the platform ever stops providing an address.
- The counters are themselves storage, so they carry `expiresAt`, and
  the TTL policy was run and verified rather than recorded as an
  intention.

---

## 7. Infrastructure claims are the easiest to fake and the least tested

Four in this cycle, each of which looked done and was not.

**"The TTL policy is configured."** `gcloud` prints `Updated field`
immediately and the policy sits in `CREATING`. It stayed there across
three checks over about three minutes before reaching `ACTIVE`. **A
policy stuck at `CREATING` deletes nothing while looking exactly like
one that works.** The method is a read-back (`ttls list`), not the
command's own success message.

**"The function is deployed."** Verified by reading the deployed
function's own configuration back: `state: ACTIVE`, `updateTime`, and
critically its `secretEnvironmentVariables` list, which contains only
`REVENUECAT_WEBHOOK_SECRET`. That list is the proof that the held
part 3 did **not** go out with it. Deploying from a worktree at an
earlier commit is only as good as the check that it did what was
intended.

**"A missing secret blocks its own function."** It does not. Measured
with `firebase deploy --dry-run`:

```
firebase deploy --only functions:recomputeRanks --dry-run
Error: In non-interactive mode but have no value for the secret:
REVENUECAT_REST_API_KEY
```

`recomputeRanks` neither uses nor knows about that key. The CLI
validates every declared secret while analysing the source, before
filtering to the requested function, so **one unshipped secret blocked
every deploy in the repo for a day**, including the ranking engine.
It went unnoticed because the single deploy performed in that window
ran from a worktree at an earlier commit: the one path that could not
have revealed it.

Three sub-traps, each measured while fixing it:

1. It is the `defineSecret()` **call** that registers the requirement,
   not the `secrets: [...]` array. The first fix made only the array
   conditional and failed identically.
2. **Shell environment variables do not reach the CLI's source
   analysis.** `VOUCH_X=true firebase deploy` cannot switch anything
   read from `process.env` at module scope.
3. A `functions/.env` file does not reach it either.

Both negatives were established with a **positive control**: a
module-scope probe that throws when its variable is set. It never
fired under the CLI and fired immediately under
`node -e "require('./lib/index.js')"`. Without the control, "the probe
did not fire" is indistinguishable from "the probe never ran", which
is the same shape as a grep that returns zero for everything.

**"Lint is clean."** It had been failing since `7a693f2` on one 81
character test name. Not cosmetic: lint is a `firebase.json` predeploy
step, so the next `firebase deploy` would have stopped at the gate.
Found only because lint ran **before** the commit rather than after.

**The rule.** *A success message is not a measurement, and a negative
result needs a positive control.* Infrastructure state is read back
from the system that holds it, never inferred from the command that
was supposed to change it.

---

## 8. Content: what renders is a claim about the world

**The claim.** The app's text and images describe real restaurants.

**Why it needs a method.** `docs/REACHABILITY_SWEEP.md` asked whether
a path can render. It passes `description` trivially: populated on 40
of 57, code around it perfect. That field carried the worst falsehood
in the codebase. **A second audit was needed, asking not "does it
render" but "is it true."**

**The method.** `docs/CONTENT_PROVENANCE_AUDIT.md` traces every
user-visible field to the script that wrote it and asks what it
asserts about the world. The data drew the line by itself: Atlanta
carried 0 descriptions and 17 real `placeId`s and coordinates; the
four scaffold cities carried 10 descriptions each and `0,0`
coordinates, a real point in the Gulf of Guinea.

**What followed, and the rule it produced.** 33 of 50 insider notes
came from a hardcoded object in a seed script, one of them paraphrasing
the `description` three lines above it. Deleted, and the source object
emptied in the same commit so a `--force` run could not restore them.
**The disqualifier is provenance, not accuracy:** verification later
showed four of seven *suspected* fabrications were in fact true. That
is an argument for deleting the population and re-adding verified
facts one at a time, not against it.

**The same rule, pointed at images.** Rather than asking Andrew to
certify 59 files from memory, which is a test anyone passes regardless
of the truth, the metadata was read:

| Bucket | Count |
|---|---|
| Camera EXIF consistent with a phone | **0** |
| `exif:UserComment: Screenshot` | **59** |
| No metadata at all | 0 |

Fifty-nine different arbitrary dimensions, consistent with cropping a
capture. A later batch of eleven downloads at exactly 1080x1350,
Instagram's portrait size, with no EXIF. `site/img/mensho.jpg`, live
on vouchfood.com, is byte-identical to one of them.

**The caveat is kept prominent, because it is what makes the
measurement honest:** a screenshot of Andrew's own photograph carries
the same marker. **The measurement narrows the question, it does not
answer it.** `docs/PHOTO_MANIFEST.md` is the record so it is never
asked from memory again.

**The rule.** Rule 17 applied to content: *a claim that lives only in
someone's recollection becomes untrue by default the moment they stop
being the one asked.*

---

## 9. Mechanisms that work, downstream of paths that do not exist

The cycle's last measurement is its most representative finding.

**The claim.** The list is open: a restaurant the editors did not
choose can climb it.

**The method, half one.** Run the real engine.
`functions/src/open_list.test.ts` puts a newcomer with no
`displayOrder` against ten curated restaurants:

| Incumbents hold | Rank 10 | Rank 5 | Rank 1 |
|---|---|---|---|
| 0 each (launch) | **4 votes** | 14 | **20** |
| 5 each | 8 | 15 | 20 |
| 20 each (curation expired) | 21 | 21 | 21 |

Not decorative. It also corrects the design's own headline: "17 net
votes from last to first" describes a *curated* rank 10, which carries
its own baseline and does not enlarge the city. A newcomer needs 20.
The numbers are pinned as assertions on **vote counts** rather than on
constants, so a future change to `BASELINE_STEP` fails with "a
newcomer now needs 40 votes to reach rank 1" rather than "expected 2.0
to be 3.0".

**The method, half two, and the actual finding.** Nothing can arrive.
`submitSuggestion` writes to `suggestions` with `status: "pending"`
and nothing reads that collection except the account-deletion cascade.
Every restaurant-writing script writes a whole city roster; **there is
no script, screen or trigger that adds one restaurant to a live city.**

**The rule.** *Measure the mechanism and the path separately.* A
mechanism that works is not a feature that exists. This is findings 2
and 11 again, one layer up: the arithmetic is correct, the road to it
was never built.

**A trap recorded for the day it is built.**
`scripts/backfill_display_order.js` sets `displayOrder = rank` on every
document lacking it, and its header correctly calls that idempotent. A
newcomer's absent `displayOrder` is not a gap, it is the thing that
makes it compete on votes alone. One run of that script after a
newcomer arrives grants it a curated baseline at whatever rank it had
reached, silently. **The script is not wrong; its precondition
expired.**

---

## 10. Numbers, so the next reviewer can re-measure

| | At `39c3edf` (cycle start) | Now |
|---|---|---|
| Flutter tests | 349 | **402** |
| Functions tests | 135 | **222** |
| Rules tests | 91 | **112** |
| `flutter analyze` | 0 issues | 0 issues |
| `functions` lint | 1 error (undetected) | 0 problems |

Production, measured through the Admin SDK:

| | Before | After |
|---|---|---|
| Sum of stored `voteCount` | **-797** | 0 |
| Documents with negative `voteCount` | 33 | 0 |
| Documents disagreeing with their votes subcollection | 33 | 0 |
| Restaurants carrying `displayOrder` | 27 of 57 | 57 of 57 |
| Generated insider notes in production | 50 | 17 |
| Restaurants in the shipped seed | 57 | 25 |

```bash
export PATH="$(brew --prefix openjdk)/bin:$PATH"
flutter test --exclude-tags=golden                       # 402
firebase emulators:exec --only firestore,auth --project vouch-test \
  'cd functions && npx jest --forceExit'                 # 222
(cd test-rules && npm run test:emulator)                 # 112
(cd functions && npm run lint && npm run build)
firebase deploy --only functions --dry-run --project majorcitymusteats
```

---

## 11. What this review does not close

Stated plainly, because a review that reads as finished is the shape a
reader has learned to distrust.

- **App Check is unenforced on every service.** Launch blocking.
  Enforcement is deliberately bound to external TestFlight traffic:
  4 users and no live city cannot tell coverage from capability.
- **Two secrets do not exist**, so finding 5's parts 2 and 3 are built,
  tested, switched off in code, and undeployed.
- **Photograph provenance is unanswered**, so the Storage migration is
  stopped rather than blocked: nothing is prepared or converted,
  because the likely resolution changes the input.
- **Finding 6 is designed and not built.** One open question remains,
  the deletion job's identifier and retention.
- **Finding 13 is untouched**: 40 restaurants carry `0,0` coordinates
  and five carry a non-address that renders today.
- **The teaser projection is deferred whole**, deliberately, rather
  than shipped write-first with no reader.
- **Houston is unpublished** pending photographs, insider notes and
  neighbourhood strings, all of which are Andrew's to supply.
- **`site/index.html` carries an unstaged redesign**, 219 insertions
  and 206 deletions, sitting in the working tree for days.
- **`CLAUDE.md`'s test counts are stale** (349/135/91). They were
  correct when written at the start of this cycle.
