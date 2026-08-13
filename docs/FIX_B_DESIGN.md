# Fix B: the curated baseline

Design only. Nothing here is built.

Fix A (`9f0e512`) changed the rank tie-break from alphabetical to
`displayOrder`, which fixed the zero-vote case. It left the inversion
that Fix B is for: **one vote still lifts rank 10 to rank 1.**
Confirmed by execution, not argued: a single vote on Lotus Seafood
produced `score = 0.997` against nine restaurants at `0.000`.

## The problem stated precisely

`computeScore` returns `0` for a restaurant with no votes
(`rank_engine.ts:53`). So the gap between "nobody has voted for this
yet" and "one person voted once" is the entire distance between last
place and first. A curated Top 10 published on a Monday can be
completely reordered by Tuesday by one person.

That is not a ranking system reacting to evidence. It is a ranking
system with no prior.

## What the baseline is, and what it must never be

A **baseline** is a starting score derived from the curated position,
which decays to exactly zero as the city accumulates real votes.

Three hard constraints, in order of importance.

**1. It is never routed through vote weight.** `firestore.rules:82`
enforces `request.resource.data.weight == 1` on every vote write, and
`test-rules/src/firestore.rules.test.ts:304` pins the denial. That
guarantee is what makes "money cannot buy rank" true rather than
aspirational. The baseline is a separate additive term computed at
rank time. It never creates a vote document, never sets a weight,
never touches `VoteRecord`. If a future reader can point at the
baseline and say "so weight is not always 1," the design has failed
regardless of how well it ranks.

**2. It reaches exactly zero, at a named constant.** Not
asymptotically small. Zero. After that, rank is votes and nothing
else. A thumb that never lifts makes "locals decide" quietly untrue,
and "quietly" is the part that matters: nobody would be able to tell.

**3. It expires on evidence, not on the calendar.** Decay is driven by
how many votes the city has cast, not by how long the city has been
open. A city nobody has voted in has learned nothing, and waiting
does not change that.

## Two correctness properties, confirmed

Both are invisible if right and fatal if wrong, so they are recorded
here rather than assumed.

### The baseline derives from `displayOrder`, never from live `rank`

**Confirmed.** `positionValue` below takes `displayOrder` and nothing
else. `rank` is never read as an input to the baseline anywhere in
this design.

This is not a preference. `rank` is the **output** of the computation
the baseline feeds. Deriving the baseline from current `rank` would
mean the baseline that produced today's order becomes an input to
tomorrow's, which is positive feedback: the order locks itself in,
votes can never dislodge it, and the only thing that ever releases it
is the decay. A restaurant that rose on real votes would then be
defended by a baseline it earned by rising, which is precisely
backwards.

`displayOrder` is safe to read because nothing in the pipeline writes
it. It is set once by the launch-order scripts and read thereafter.
`rank_recompute.ts` writes `rank`, `rankScore` and `voteCount`, and
must never be extended to write `displayOrder`.

### The baseline weight is monotonically non-increasing

**Required, with a test.** `baselineWeight` must never rise between
two runs of the same city.

Driving decay from lifetime city votes gives this for free, because
that count only grows. But "for free" is exactly how the
composition-root class of bug gets in: the property holds because of
something two layers away, nobody asserts it, and then somebody
changes the something. A weight that can rise is a list that
un-learns, and it must be impossible rather than merely unlikely.

The test is a property test over the pure function, not an
integration test:

```ts
// baselineWeight must never increase as votes accumulate.
test("baseline weight is monotonically non-increasing", () => {
  let previous = Infinity;
  for (let votes = 0; votes <= 1000; votes++) {
    const w = baselineWeight(votes, 10);
    expect(w).toBeLessThanOrEqual(previous);
    expect(w).toBeGreaterThanOrEqual(0);
    previous = w;
  }
  expect(baselineWeight(200, 10)).toBe(0);
  expect(baselineWeight(10_000, 10)).toBe(0);
});
```

The clamp at zero is asserted in the same test because
`1 - votes/expiry` goes negative past expiry, and a negative baseline
would actively penalise a curated restaurant for its position, which
is the opposite of the intent and would be very hard to notice.

## The constants

```ts
/**
 * Score units between adjacent curated positions.
 *
 * Deliberately expressed as "how many fresh votes does it take to
 * move one place," because that is the sentence the product has to
 * be able to say out loud. A fresh vote is worth exactly 1.0
 * (computeScore, age 0), so a step of 2.0 means one place costs two.
 *
 * Set to 2.0 rather than 1.0 on manipulation cost, not on feel. At
 * 1.0, nine friends buys rank 1 on launch day. At 2.0 it is
 * seventeen. See "Constant 1" below for the full table, including why
 * 3.0 is rejected.
 */
export const BASELINE_STEP = 2.0;

/**
 * City votes per restaurant at which the baseline reaches zero.
 *
 * Scales with city size: a 10 restaurant city expires at 200 votes,
 * a 17 restaurant city at 340. A larger curated list is a larger
 * editorial claim and takes proportionally more evidence to overturn.
 */
export const BASELINE_EXPIRY_VOTES_PER_RESTAURANT = 20;
```

## The curve

```
n            = restaurants in the city
cityVotes    = lifetime vote documents in the city (monotonic, not decayed)

positionValue(d) = d == null ? 0 : (n - d + 1) * BASELINE_STEP
expiryVotes      = n * BASELINE_EXPIRY_VOTES_PER_RESTAURANT
baselineWeight   = max(0, 1 - cityVotes / expiryVotes)

baseline = positionValue(displayOrder) * baselineWeight
score    = computeScore(votes, now) + baseline
```

Linear, because it has to hit zero exactly at a stated number and an
exponential never does. The whole point of constraint 2 is a hard
stop, and a curve that merely gets very small cannot provide one.

`cityVotes` is the **raw lifetime count**, not the time-decayed sum.
A city that has been evaluated has been evaluated; that is a one-way
fact and the counter should not walk backwards. The consequence is
named under Properties below.

## Worked numbers, Houston, n = 10, expiry = 200

At `BASELINE_STEP = 2.0`:

| cityVotes | weight | rank 1 baseline | rank 5 | rank 10 | one place costs |
|---|---|---|---|---|---|
| 0 | (guard fires, see below) | | | | |
| 20 | 0.90 | 18.00 | 10.80 | 1.80 | 1.80 |
| 50 | 0.75 | 15.00 | 9.00 | 1.50 | 1.50 |
| 100 | 0.50 | 10.00 | 6.00 | 1.00 | 1.00 |
| 180 | 0.10 | 2.00 | 1.20 | 0.20 | 0.20 |
| **200** | **0.00** | **0.00** | **0.00** | **0.00** | **0.00** |

**The inversion, before and after.** One fresh vote on the curated
rank 10, city at 20 votes:

- Today: `0.997` against `0.000`. Rank 10 becomes rank 1.
- With the baseline: rank 10 scores `1.80 + 0.997 = 2.797`. Rank 9
  scores `3.60`. It moves **no** places on one vote, and needs two.

**Climbing.** From curated 10 to curated 1 needs 9 net votes at
`STEP = 1.0` and 17 at `2.0`. See the table under Constant 1, which
solves for the feedback rather than estimating it.

**Time to expiry.** Answered properly under Constant 2. It is
unmeasured, the plausible range is three weeks to three months, and
that uncertainty is why the opening-list string is a requirement.

## A restaurant with no baseline

`displayOrder == null` gives `positionValue = 0`, so **baseline is
zero and the restaurant competes on votes alone.**

This is the correct default and it is deliberate. A restaurant nobody
curated has nobody vouching for its position, so it gets no thumb. It
is also what the open list produces: a user-suggested restaurant
arrives with no curated position by definition.

Fix A already sorts absent `displayOrder` last on an exact tie, so
the two mechanisms agree rather than fighting.

**The tension worth stating plainly.** During the baseline window a
newcomer must out-vote a decaying thumb. At 20 city votes it needs
about 1 net vote to pass curated rank 10, about 6 to pass curated
rank 5, and about 9 to reach rank 1. That is climbable, which is the
test the brief sets ("if the baseline takes hundreds of votes to
expire, the open list is decorative"). At `BASELINE_STEP = 2.0` and
20 votes per restaurant it is not decorative: 17 net votes from last
to first. At a step of 5.0, or an expiry of 200 votes per restaurant,
it would be. Those two constants
are where this design can be quietly ruined, which is why they are
named constants with this paragraph attached.

## Andrew's guard, the outer layer

**If a city's total vote count is zero, write nothing at all.** Not a
zero baseline, not a no-op batch. Skip the city entirely, before the
batch is built.

This is the strongest of the three protections because it does not
depend on any of the arithmetic above being right. A city with no
evidence has its curated ranks left exactly as seeded, and no
recompute can touch them.

It also means the first run against a newly published city is a
no-op, and Fix A's tie-break becomes a backstop for partial-vote ties
rather than the primary mechanism for the launch case.

## Properties, including the awkward ones

**A quiet city reverts to curation.** Vote scores decay with a 90 day
half life; the baseline does not decay with time. So in a city that
got 30 votes and then went silent, the votes fade toward zero over
years while the baseline holds at `weight = 0.85`, and the curated
order gradually reasserts itself. This is a property, not a bug: if
the evidence has decayed away, falling back to the editorial position
is the honest answer. It should be stated in `DECISIONS.md` rather
than discovered.

**A long-quiet city past expiry falls to the tie-break.** Once
`cityVotes >= expiryVotes` the baseline is permanently zero. If those
votes are then years old, every score decays toward zero and Fix A's
`displayOrder` tie-break carries the ordering. That is the intended
end state and is why Fix A is not made redundant by Fix B.

**Restaurant deletion changes `n`.** `positionValue` and `expiryVotes`
both depend on the city's restaurant count, so removing a restaurant
shifts every baseline. Acceptable, since it is recomputed from live
data every run rather than stored, but it means a deletion can move
ranks without any vote changing. `logCitySummary`'s jump anomaly will
surface it.

## Observability

**Write `baselineScore` to the document** alongside `rankScore`, in
the same batch. Write-only: it is computed from `displayOrder` and
`cityVotes` every run and is **never read back as an input**.

That distinction is the lesson of this whole remediation.
`cities.restaurantCount` and `restaurants.voteCount` both drifted
precisely because a stored value was read as truth. A derived value
written for observation cannot drift into being wrong, because
nothing depends on it.

**Keep the existing anomalies, and say where they surface.** They
were right and nobody was reading them. They are `logger.warn` from
`rank_recompute.ts :: logCitySummary`, which lands in **Cloud
Logging** for the `recomputeRanks` function, filterable on
`[rank] ANOMALY`:

- `ANOMALY: zero restaurants for live city` (`rank_recompute.ts:66`)
- `ANOMALY: all N scores identical` (`:183`)
- `ANOMALY: X jumped N positions` (`:197`)

The second one is worth keeping specifically because the baseline
makes identical scores *less* likely, so if it fires after Fix B
ships, something is wrong with the baseline rather than with the
data.

**One new log, once per city per run:** the baseline weight and
whether it has expired. Without it, "why did the order change" has no
answer, and the ranking becomes the same kind of unexplainable box
the alphabetical tie-break was.

## The teaser projection, in the same batch

Deferred here from phase 8 for a reason that only holds at this point
in the work: the batch is already open.

One publicly readable document per city holding `{rank, cuisine,
neighbourhood}` for ranks `kGatedRankStart` to `kGatedRankEnd`,
written by `recomputeAllRanks` **inside the same batch that sets
rank**. In sync by construction rather than by a job that can fall
behind.

Written by any other path it would be a fourth drifting
denormalization alongside `cities.restaurantCount` and comment
`userName`. This is the only moment in the codebase where it can be
made correct for free.

Not blocked on secrecy: vouchfood.com already publishes exactly that
pairing for the gated band on the open web.

## Build order

1. The guard. Standalone, smallest, and it protects the launch case
   on its own even if nothing else lands.
2. The constants, the pure `baselineWeight()` and `baselineFor()`
   functions in
   `rank_engine.ts`, with the zero-vote and one-vote fixtures from the
   Fix A tests extended to assert the new scores, plus the
   monotonicity property test above. Red first.
3. Wire it into `recomputeAllRanks`, plus `baselineScore` on the
   write.
4. The new anomaly log, and `baselineWeight` written to the city
   document so the screen can render the opening-list line without a
   second implementation of the curve.
5. The opening-list string on the city screen, which is a requirement
   rather than polish.
6. The teaser projection in the same batch.

Steps 1 and 2 are independently shippable and independently valuable.

## Constant 1: what rank 1 costs in friends

"Climbability" was the wrong frame and it produced the wrong
question. The right one: **what does rank 1 cost in friends?**

Money cannot buy rank on Vouch, and that is enforced at the rules
layer. Friends buying rank is the same product failure in a cheaper
currency, and during the launch window the baseline is the only thing
standing in its way, because volume is too low for anything else to
be.

### What already limits it, measured

| Control | State | Where |
|---|---|---|
| One vote per user per restaurant | **Structural, not a check** | `firestore.rules:77` `match /votes/{userId}` with `allow create: if isOwner(userId)`. The document id **is** the uid, so a second vote is the same path. |
| Cannot change a vote | Enforced | `allow update: if false` |
| Verified email required | Enforced | `isEmailVerified()` on create |
| App Check | **Activated, NOT enforced** | `lib/main.dart:34` says "monitor-only (enforcement is a separate console step)". Zero `enforceAppCheck` matches in `functions/src/`. |
| Rate limit on vote creation | **None** | |

So the attack cost is **one account with a verified email per vote.**
That is a real barrier against a script and almost none against ten
friends, which is exactly the case that matters. App Check being
monitor-only means it currently contributes nothing here.

### The table

Net fresh votes the challenger needs, solved rather than estimated,
because the challenger's own votes raise `cityVotes` and therefore
lower everyone's baseline including the incumbent's.

**Launch. The challenger is the only voter in the city and the
incumbent has no votes.** This is the exposed case.

| `BASELINE_STEP` | rank 10 to rank 1 | rank 5 to rank 1 | one place |
|---|---|---|---|
| 1.0 | **9** | 4 | 1 |
| 2.0 | **17** | 8 | 2 |
| 3.0 | **24** | 12 | 3 |

**Warm. The city has 100 organic votes and the incumbent holds 15.**

| `BASELINE_STEP` | rank 10 to rank 1 | rank 5 to rank 1 | one place |
|---|---|---|---|
| 1.0 | 19 | 17 | 1 |
| 2.0 | 23 | 19 | 1 |
| 3.0 | 26 | 20 | 2 |

The warm rows converge because the incumbent's real votes dominate
the baseline. That is the healthy regime, and it is the regime the
expiry constant exists to reach.

### Recommendation: 2.0

The launch row is the whole argument. At 1.0, **nine friends buys
rank 1 on day one**, and nine people is nothing. At 2.0 it is
seventeen, which doubles the cost of a friends-and-family push while
leaving "twenty net votes from last to first" comfortably inside the
weeks target the brief set.

**A correction to my own reasoning here, because the first version of
this argument was wrong.** I initially rejected 3.0 on the grounds
that a single vote would no longer move a restaurant a place. Once
the numbers were computed rather than reasoned about, that turns out
to be true of 2.0 as well: at launch weight `0.90`, one place costs
`STEP * 0.90`, so a single `0.997` vote clears it at 1.0 and clears
neither 2.0 nor 3.0.

The real distinction is when a single vote starts mattering, and it
is a function of the weight rather than of the step alone:

| | one vote moves a place at |
|---|---|
| 1.0 | launch, weight 0.90 |
| 2.0 | weight 0.50 and below, about 100 city votes |
| 3.0 | weight 0.33 and below, about 134 city votes |

So 2.0 means a single vote moves nothing for roughly the first half
of the opening period, then moves a place for the rest of it, then
means everything once the baseline is gone. That is a real cost and
it is the honest reason to prefer 2.0 over 3.0 rather than the
cleaner claim I made first: 3.0 extends the dead period by another
third, and the opening-list string has to carry the explanation for
however long it lasts.

**2.0 makes rank 1 cost seventeen people rather than nine, at the
price of a single vote being invisible until the city reaches about
100 votes.** That trade is the recommendation, stated with its cost
rather than without it.

## Constant 2: wall clock, and a hard UI requirement

The constant is defensible. Whether it is **honest** depends entirely
on how long 200 votes takes, and that is unmeasured: production holds
zero votes today.

The arithmetic, so Andrew can substitute his own numbers:

| Share of installs that vote | Votes each | Installs to reach 200 |
|---|---|---|
| 10% | 2 | 1,000 |
| 25% | 2 | **400** |
| 50% | 2 | 200 |

At 25% voting twice each, that is 0.5 votes per install:

| Installs per day | Days to expiry |
|---|---|
| 5 | 80 |
| 20 | 20 |
| 50 | 8 |

So the honest answer is a range from three weeks to nearly three
months, and nobody knows which. **That uncertainty is why the
following is a requirement rather than a nicety.**

### While the baseline is above zero, the city screen says so

Not optional, and not a polish item to defer.

While `baselineWeight > 0`, the city screen carries a line saying the
list is still opening. When the weight reaches zero, the line
disappears and the list is simply ranked by locals.

Draft copy, for Andrew to rewrite in his own voice:

> **Opening list.** Ranked by locals as votes come in.

And on expiry, nothing at all. The absence is the signal.

That one string is the difference between a thumb on the scale and a
lie. It costs nothing, it makes the mechanism visible to the people
it affects, and it converts the expiry constant from a number nobody
sees into a promise the app visibly keeps.

It also removes the pressure on constant 2. A longer expiry stops
being dishonest once the app is telling the truth the whole way, so
Andrew can choose the number on product grounds rather than on how
much silence he is willing to tolerate.

**Design note.** The screen needs `baselineWeight` to render this,
and it must not recompute it: that would be a second implementation
of the curve, drifting against the first. `recomputeAllRanks` should
write the weight to the city document as `baselineWeight` in the same
batch, alongside the per-restaurant `baselineScore`. One writer, one
number, read-only everywhere else.

## Constant 3: scale with `n`, confirmed

**The step is the user-facing quantity.** "One vote moves you one
place" has to mean the same thing in Houston and in Atlanta, and
scaling the baseline with city size is what preserves it.

The alternative, a fixed top value interpolated down, compresses the
steps in a larger city: a vote in Atlanta would be worth nearly two
places while a vote in Houston is worth one. That is arbitrary, and
it makes the list more volatile exactly where there is more of it to
be volatile about.

Atlanta expiring at 340 votes against Houston's 200 is a consequence
rather than a side effect. A longer list is a larger editorial claim
and needs proportionally more signal before its curation should stop
mattering.

## Decided

- **`BASELINE_STEP = 2.0`.** Seventeen people for rank 1 against nine.
- **`BASELINE_EXPIRY_VOTES_PER_RESTAURANT = 20`,** unchanged. The
  long end of the three-week-to-three-month range is acceptable
  precisely because the opening-list line is saying so the whole time.
  Given finding 14, a longer baseline is also doing more protective
  work than a shorter one, which argues against reducing it.
- **Scaling with `n`,** confirmed.

### A vote must be visibly acknowledged even when it cannot move a rank

At `STEP = 2.0` a single vote moves nothing until the city reaches
about 100 votes. That is correct behaviour, one vote should not
reorder a top ten, but it means a user taps vote and the ranking
tells them nothing happened for the whole opening period. A vote that
appears to do nothing is a vote people stop casting.

**Confirmed already in place, no work needed:**

| | |
|---|---|
| Optimistic local update | `app_state.dart:618-624`, `voteCount ± 1` |
| Rendered before the network call | `notifyListeners()` at `:628` runs **before** the `await` at `:635` |
| Haptic confirmation | `HapticFeedback.lightImpact()` at `:626` |
| Displayed on the detail screen | `vote_button.dart:105` renders `formatCount(voteCount)` unconditionally |
| Rolls back on failure | the existing `toggleVote` rollback from finding 1 |

One detail worth knowing rather than discovering. `restaurant_card.dart:19`
sets `showVotes = restaurant.voteCount > 0`, so a card hides its count
at zero. At launch every count is zero, so the first vote makes the
count **appear** rather than incrementing a visible number. That is
arguably stronger feedback than `0 -> 1` would be, and it is not a
defect, but it should be a deliberate choice rather than an accident,
so it is recorded here.

**No work ships with Fix B for this.** The mechanism exists and is
immediate.

## Blocked on finding 14

Every manipulation number above assumes a vote costs a person. App
Check is unenforced on every service, so today a vote costs an email
address. `BASELINE_STEP = 2.0` is the right choice for the casual
case, a restaurant owner telling friends, and it is close to
irrelevant against a script. See `docs/FINDING_14_APP_CHECK.md`.
