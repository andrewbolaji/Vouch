# The open list, measured

2026-08-18. Read only, plus one new test file. Nothing about the
ranking engine changed.

`docs/FIX_B_DESIGN.md` sets the test in words: "if the baseline takes
hundreds of votes to expire, the open list is decorative." It answers
it with arithmetic done by hand, and the answer was right in order of
magnitude and wrong in detail. This runs the real engine instead.

Two halves, and the second one matters more than the first:

1. **Can a newcomer climb?** Measured. Yes.
2. **Can a newcomer arrive at all?** Measured. **No path exists.**

## 1. The climb, from the real engine

`functions/src/open_list.test.ts` runs `assignRanks` and `baselineFor`
over the real constants. Ten curated restaurants with `displayOrder`
1 to 10, plus one newcomer with no `displayOrder`, so `n` becomes 11
and the newcomer earns no baseline. Self-consistent: the newcomer's
own votes count toward the city total that drives the decay, because
in a real city they do.

**Votes the newcomer needs:**

| Incumbents hold | Reach rank 10 | Rank 5 | Rank 3 | Rank 1 |
|---|---|---|---|---|
| 0 each (launch day) | **4** | 14 | 17 | **20** |
| 1 each | 5 | 14 | 17 | 20 |
| 5 each | 8 | 15 | 18 | 20 |
| 20 each (curation expired) | 21 | 21 | 21 | 21 |

**The open list is not decorative.** Four votes puts a restaurant
nobody curated onto the list, and twenty takes it to the top of a
launch city. Those are numbers a real neighbourhood can produce in a
week.

**The design's headline number is off by three for this case.**
FIX_B_DESIGN says "17 net votes from last to first". That is a
*curated* rank 10, which carries its own small baseline and does not
change the size of the city. A newcomer carries none and makes `n`
eleven, and it needs **20**. Same order, different number, and the
difference is the entire reason for measuring rather than quoting.

**The last row is the design working, not failing.** Once every
incumbent holds 20 votes the city is at 200 of its 220 vote expiry,
the baseline is nearly gone, and the contest is votes alone. All four
targets collapse to 21 because the incumbents are tied on 20 and a
single extra vote passes all of them at once.

### What a newcomer does to everybody else

Not obvious, and it goes the other way from what you would want:

| | Curated rank 1 | Curated rank 10 |
|---|---|---|
| Baseline at n=10, 20 city votes | 18.0 | 1.8 |
| Baseline at n=11, 20 city votes | 20.0 | **3.636** |

Two things move at once. Position value is
`(n - displayOrder + 1) * STEP`, so every incumbent gains a step. And
the expiry scales with `n`, so 20 votes is a smaller fraction of the
way to expiry than it was, and the weight is higher.

So **each restaurant the open list admits makes the curated order
harder to displace for the next one**, and the effect is far from
even: curated first place gains 11 percent of its protection, curated
last place doubles its own. The expiry moves from 200 votes to 220 for
everyone.

This is not an argument against the design. It is a property nobody
had stated, it is small at one or two newcomers, and it compounds.
Worth knowing before a city admits ten.

## 2. There is no way in

The climb only matters if something can arrive. Nothing can.

**`submitSuggestion` writes to `suggestions` with `status: "pending"`,
and nothing ever reads that collection.** The only other code that
touches it is `user_cleanup.ts`, which deletes a user's suggestions
when they delete their account. There is no admin screen, no script,
no trigger, no documented console workflow that turns a suggestion
into a restaurant document.

Every script that writes restaurants writes a whole city roster:
`seed_houston_new.js`, `seed_atlanta.js`, `seed_production.js`. There
is **no script that adds one restaurant to a live city.** Searched for
one; there is not one.

So "the open list" is currently a property of the ranking engine and
not a feature of the product. A restaurant that Andrew adds by hand in
the Firebase console, with no `displayOrder`, would climb exactly as
measured above. Nothing else can put it there, and nothing tells a
user who suggested a restaurant that anything happened.

This is the same shape as findings 2 and 11: a mechanism that works
perfectly, downstream of a path that does not exist.

## 3. A trap that will convert the mechanism into a bug

`scripts/backfill_display_order.js` sets `displayOrder = rank` on
every restaurant that lacks it. Its own header calls that idempotent
and says it "removes the absent-displayOrder branch from production
entirely", which was exactly right in August, when every document was
curated and the absent branch was an accident.

**An open-list newcomer's absent `displayOrder` is not an accident. It
is the thing that makes it compete on votes alone.** Run that backfill
once after a newcomer arrives and the newcomer is granted a curated
baseline at whatever rank it had climbed to, permanently, and nothing
reports it. The script is not wrong; its precondition expired.

Cheap fix when the open list becomes real: have it skip documents
created after the city's launch, or take an explicit list of ids, or
refuse to run against a city whose vote total is above zero. Not doing
that today, because the open list has no path in and the script has no
remaining reason to run.

## What was added to the repo

`functions/src/open_list.test.ts`, six tests, pinning the numbers
above. They are assertions on vote counts rather than on constants on
purpose: if `BASELINE_STEP` or the expiry is ever changed, the failure
should read "a newcomer now needs 40 votes to reach rank 1" rather
than "expected 2.0 to be 3.0", because the first sentence is one
anybody can judge and the second needs this document to interpret.

One of those tests was wrong on its first run, asserting 4.0 where the
engine says 3.636, because it counted the extra step and forgot that
the expiry moves too. The corrected expectation and the reason are
both in the test.
