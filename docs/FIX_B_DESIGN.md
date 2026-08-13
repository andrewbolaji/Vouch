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

## The constants

```ts
/**
 * Score units between adjacent curated positions.
 *
 * Deliberately expressed as "how many fresh votes does it take to
 * move one place," because that is the sentence the product has to
 * be able to say out loud. A fresh vote is worth exactly 1.0
 * (computeScore, age 0), so a step of 1.0 means one place costs one
 * vote.
 */
export const BASELINE_STEP = 1.0;

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

| cityVotes | weight | rank 1 baseline | rank 5 | rank 10 |
|---|---|---|---|---|
| 0 | (guard fires, see below) | | | |
| 20 | 0.90 | 9.00 | 5.40 | 0.90 |
| 50 | 0.75 | 7.50 | 4.50 | 0.75 |
| 100 | 0.50 | 5.00 | 3.00 | 0.50 |
| 180 | 0.10 | 1.00 | 0.60 | 0.10 |
| **200** | **0.00** | **0.00** | **0.00** | **0.00** |

**The inversion, before and after.** One fresh vote on the curated
rank 10, city at 20 votes:

- Today: `0.997` against `0.000`. Rank 10 becomes rank 1.
- With the baseline: rank 10 scores `0.90 + 0.997 = 1.897`. Rank 9
  scores `1.80`. It passes one place, not nine.

**Climbing.** For a restaurant to go from curated 10 to curated 1 at
20 city votes it needs to beat `9.00`, so roughly 9 fresh votes more
than the incumbent. At 100 city votes that is 5. At 200 it is zero,
and position is irrelevant.

**Time to expiry.** 200 votes at 10 per day is 20 days. That is the
"weeks" the brief asks for. If real traffic makes this too slow or
too fast, `BASELINE_EXPIRY_VOTES_PER_RESTAURANT` is the single number
to turn, and it should be turned on measured vote rate rather than on
a guess. **This has not been measured; there are zero votes in
production today.**

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
expire, the open list is decorative"). At `BASELINE_STEP = 1.0` and
20 votes per restaurant it is not decorative. At a step of 5.0, or an
expiry of 200 votes per restaurant, it would be. Those two constants
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
2. The constants and the pure `baselineFor()` function in
   `rank_engine.ts`, with the zero-vote and one-vote fixtures from the
   Fix A tests extended to assert the new scores. Red first.
3. Wire it into `recomputeAllRanks`, plus `baselineScore` on the
   write.
4. The new anomaly log.
5. The teaser projection in the same batch.

Steps 1 and 2 are independently shippable and independently valuable.

## Open questions for Andrew

1. **`BASELINE_STEP = 1.0`**, so one curated place costs one fresh
   vote. Right feel, or should a place cost more?
2. **`BASELINE_EXPIRY_VOTES_PER_RESTAURANT = 20`**, so Houston's
   baseline is gone after 200 city votes. Unmeasured, and it is the
   number most likely to be wrong.
3. **Scaling with `n`.** Atlanta's rank 1 gets a baseline of 17.0
   against Houston's 10.0. The alternative is a fixed top value
   interpolated down, which compresses the steps in a larger city and
   makes adjacent positions cheaper to swap there. I prefer scaling
   with `n` and want it confirmed rather than assumed.
