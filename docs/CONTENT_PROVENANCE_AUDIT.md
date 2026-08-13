# Content provenance audit, 2026-08-13

Every user-visible field written by `scripts/seed_production.js` and
`scripts/seed_atlanta.js`, traced to its source and checked for
whether it asserts something about the real world.

This is a different audit from `docs/REACHABILITY_SWEEP.md`. That one
asked whether a path can render. This one asks whether what renders is
true. `description` passed the first audit trivially, because it is
populated and non-empty on 40 of 57 and the code around it works
perfectly. It is the field carrying the worst falsehood in the
codebase.

Nothing was fixed during this audit.

## The provenance line, drawn by the data

| City | docs | description | vibeTags | openingHours | placeId | lat/lng |
|---|---|---|---|---|---|---|
| atlanta | 17 | **0** | **0** | **17** | **17** | 17 real |
| chicago | 10 | 10 | 10 | 0 | 0 | all `0,0` |
| houston | 10 | 10 | 10 | 0 | 0 | all `0,0` |
| la | 10 | 10 | 10 | 0 | 0 | all `0,0` |
| nyc | 10 | 10 | 10 | 0 | 0 | all `0,0` |

Two populations, and the split is binary on every field.

**Atlanta (17).** Human-sourced candidate list
(`data/atlanta_candidates_seedready.csv`, commit `2b5da37`), enriched
through the Google Places API. Carries **no narrative fields at all**
and full external verification. Nothing in it asserts anything a
person would have to have observed.

**Scaffold cities (40).** Houston, Chicago, LA, NYC. Everything comes
from the hardcoded arrays in `scripts/seed_production.js`, introduced
by `162b12b` (2026-05-07), a commit whose own message calls it Block 0
scaffold. Carries **full narrative and zero external verification**.

Houston is in the scaffold population despite having been re-curated.
`set_houston_launch_order.js` rewrote `rank` and `displayOrder` only.
It never touched `description`, `vibeTags` or `locations`, so
Houston's prose is still Block 0 prose.

## Bucket 2: checkable and wrong

The count Andrew asked for. Split by confidence, because a bad entry
in this table is the same failure mode as the content it is auditing.

### Confirmed wrong

Five, after verification moved one item in and Corkscrew's star out.

| # | Field | Restaurant | Text | Why it is wrong |
|---|---|---|---|---|
| 1 | `description` | nyc r2 Di Fara Pizza | "**Dom DeMarco has been hand-cutting basil on every slice** since 1965." | Domenico DeMarco died 17 March 2022. Present perfect continuous about a named person, dead four years. Independently verified by Andrew. |
| 2 | `description` | nyc r1 Peter Luger | "**Cash only**, no menu needed. Porterhouse for two since 1887." | Peter Luger began accepting credit cards in 2021, ending a decades-long cash-only policy that was its most repeated trait. A user is told to bring cash for a $200 steak dinner on the basis of a fact that stopped being true five years ago. |
| 3 | `description` | la r1 Guerrilla Tacos | "**Chef Wes Avila** turned a taco cart into an LA institution." | Avila left Guerrilla Tacos around 2020 and has run other kitchens since. The sentence is past tense so it is not strictly false, but it is the only thing said about the restaurant and it names a chef who is not there. |
| 4 | `vibeTags` | 3 restaurants | `"Cash Only"` | Same defect as #2, in a second field. Includes Peter Luger. |
| 5 | `description` | la r8 Petit Trois | "**no-reservations** French bistro. **25 seats**." | Wrong on both counts. 21 seats at the original counter, and it takes reservations. Promoted here from the unverified list after being checked. |

**Stale-but-once-true** is worth naming as its own category. #2 and #3
were both accurate when written. A user who brings cash for a two
hundred dollar steak dinner on the strength of #2 is harmed by that
sentence in a way that "it used to be right" does not repair.

### Verified, in both directions

The first version of this file listed these seven as "needs
verification" and singled out Corkscrew BBQ's Michelin star as the
most serious item on the list. **That was wrong, and the direction of
the error is the lesson.**

I compiled the list by looking for fabrications, so a true claim that
looked like the kind of thing a scaffold invents got filed as a
suspected invention. A generator that produces plausible text will
sometimes produce true text. A list of "suspected fabrications"
assembled by looking only for falsehood will mislabel the true ones,
which is the same failure this audit exists to catch, pointed the
other way.

Every one has now been checked against a source and recorded as true,
false, or unverifiable.

| # | Restaurant | Claim | Verdict |
|---|---|---|---|
| 5 | houston r5 Corkscrew BBQ | "Michelin-starred in 2024." | **TRUE.** CorkScrew BBQ in Spring received a star in the inaugural MICHELIN Guide Texas, announced 11 November 2024, one of four Texas barbecue restaurants to do so. |
| 6 | houston r10 Lotus Seafood | "Five locations." | **TRUE** as of August 2026. Five Houston locations plus a food truck. A drifting count, so true today is not true indefinitely. |
| 7 | houston r4 The Peri Peri Factory | "Houston's first. Halal-certified." | **TRUE.** Houston's first peri peri restaurant, kitchen stocked with exclusively halal-certified ingredients. |
| 11 | houston r6 Lost and Found | "a famous Travis Scott mural." | **TRUE.** A colourful mural of Travis Scott in the parking lot at 160 W Gray St. People were hopping the construction fence to photograph it before the venue opened. |
| 8 | houston r1 Mensho | "Tokyo ramen master Tomoharu Shono's Houston shop. Michelin-recognized." | **MISLEADING, not false.** Shono and the Asiatown shop are real. The Michelin recommendation belongs to Mensho's San Francisco location (recommended 2017 to 2022). The sentence reads as though the Houston shop holds it. |
| 9 | la r8 Petit Trois | "no-reservations French bistro. 25 seats." | **FALSE on both counts.** The original counter seats 21, not 25, and the restaurant takes reservations, including OpenTable, large parties and private dining. |
| 10 | la r4 Jitlada | "Jonathan Gold approved." | **TRUE but invokes a dead critic.** Gold championed Jitlada and died 21 July 2018. Jitlada is still open at 5233 W Sunset Blvd as of 2026. Same shape as the Di Fara sentence, milder: a real association, written as though it were current. |

**Score: four true, one misleading, one false, one true-but-stale.**

Which is the point. Roughly two thirds of what I suspected was
invented is accurate. That is exactly why accuracy is the wrong
disqualifier, and it is the argument for the principle recorded under
Recommendation below rather than an argument against it.

### Not false, but not ours to say

| # | Field | Restaurant | Text |
|---|---|---|---|
| 12 | `description` | la r6 Langer's Deli | "The #19 pastrami sandwich might be better than Katz's. **We said it.**" |

"We said it" is the app speaking in the first person, stating an
opinion nobody at Vouch formed, about a restaurant nobody at Vouch
visited. It is the exact voice the insider notes were supposed to
carry, in the field that is supposed to be neutral.

## Bucket 3: unverifiable narrative

The majority. All 40 scaffold descriptions are written in marketing
voice regardless of whether their individual facts hold.

Representative:

- "Bold flavors, every dish fights for your attention."
- "The burger that launched a thousand wait lists."
- "Cookies the size of your fist."
- "Cuban bakery chain where the cheese rolls cause actual stampedes."
- "Texas-style BBQ in Chicago that Texans actually respect."
- "makes Angelenos wait 3 hours happily."

Nobody observed any of it. It reads as copy the restaurant did not
write and did not approve, published under Vouch's name about their
business.

**`vibeTags`, all 40 restaurants, 38 distinct values.** `Iconic` (9),
`Worth the Wait` (5), `Hidden Gem` (4), `Flavor Bomb` (4),
`Trendy` (3), `Clean Vibes` (1). Every one is a subjective judgement
presented as a data attribute. `Cash Only` (3) is the only
factually checkable tag, and it is wrong on at least one of them.

Atlanta has zero vibeTags, so this bucket is scaffold-only.

## Bucket 1: verifiable and true

**Atlanta's 17, entirely.** `cuisine`, `area`, `address`,
`openingHours`, `placeId`, coordinates. Human-sourced, Places-verified,
no narrative. Nothing here asserts an observation.

**Scaffold `cuisine`,** 40 of 40. "Ramen", "Deep dish", "Hot Chicken",
"Steakhouse". Category labels, checkable, and correct as far as I can
tell.

**Scaffold `name`,** 40 of 40. Real operating businesses.

**Scaffold founding dates** where stated: Katz's 1888, Peter Luger
1887, Russ & Daughters 1914, Jim's Original 1939, Di Fara 1965. All
correct. It is the verb tense around them that fails, not the year.

## A separate defect the audit turned up

Not veracity, but it is in the same fields and it is measurable.

| | Scaffold (40) | Atlanta (17) |
|---|---|---|
| location rows with `latitude`/`longitude` of `0,0` | **40 of 40** | 0 of 17 |
| rows whose address is not an address | **5** | 0 |

The five: Portillo's and Lou Malnati's carry `area: "Multiple
locations"`, `address: "Various, Chicago, IL"`, and three others of
the same shape. `RestaurantLocation.address` is displayed. A user
tapping through gets the string "Various, Chicago, IL".

Every scaffold coordinate is `0,0`, which is a real point in the Gulf
of Guinea. Any future map or distance feature reads all 40 as being in
the same place off the coast of Africa. Atlanta's are real, from
Places.

## What I did not audit

- `priceLevel`. Present on all 57 but I have no basis to check it.
- Whether the 40 scaffold restaurants are still open. Two of the four
  confirmed errors are staleness, so this is worth a Places pass.
- The marketing site, which Andrew flagged as carrying the same risk
  on a surface I cannot see.

## vouchfood.com, diffed against production

Andrew supplied the live site rows. Note that the held rows were
written against the old ordering, so a rank mismatch is expected and
is not what is reported here. Only factual accuracy of each pairing is.

**Revealed rows.** All five pairings are accurate. Two describe
restaurants that are not in the app.

| Site row | Production | Verdict |
|---|---|---|
| 1 ChòpnBlọk, West African, Montrose | **absent from all 57** | Pairing correct. 507 Westheimer Rd is Montrose, cuisine is right. Not in the app. |
| 2 Mensho, Ramen, Chinatown | Mensho, Ramen, Chinatown | **Exact match.** |
| 3 CorkScrew BBQ, Barbecue, Old Town Spring | Corkscrew BBQ, BBQ, Spring | Match, and the site is **more precise**: 26608 Keith St is Old Town Spring. Casing differs, `CorkScrew` versus `Corkscrew`, which is the exact fragility that will make `LAUNCH_ORDER` and `resolveDemoAsset` miss silently. |
| 4 Roostar, Vietnamese, East End | **absent from all 57** | Pairing correct. 2929 Navigation Blvd is East End, cuisine is right. Not in the app. |
| 5 JOEY Uptown, New American, Galleria | Joey Uptown, Globally-Inspired New American, Galleria / Uptown | Match. Site's cuisine is a shortening of production's. |

**Held rows.** Three correspond to a real production restaurant. Two
correspond to nothing.

| Site row | Nearest production restaurant | Verdict |
|---|---|---|
| 8 Sushi | Top Sushi, Japanese (Sushi), Westheimer | Cuisine matches. No neighbourhood published, so nothing to contradict. |
| 9 American, Midtown | Lost and Found, Cocktail Bar + Kitchen, Midtown | Neighbourhood matches exactly. "American" is a loose reading of "Cocktail Bar + Kitchen". |
| 10 Portuguese, Galleria | The Peri Peri Factory, Portuguese-African, Westheimer | Cuisine matches. 6375 Westheimer Rd sits in the Galleria/Uptown area, so the neighbourhood is defensible. Note this restaurant is **rank 4** in production, a revealed rank, not a held one. |
| 6 **Tex-Mex, East End** | **none** | No Tex-Mex restaurant exists in Houston in the app, and no Houston restaurant is in East End. |
| 7 **Indian, Humble** | **none** | No Indian restaurant exists in Houston in the app. "Humble" appears in the repo only in a code comment listing Houston-metro suburbs (`scripts/lib/places_enricher.js:11`). |

Searched the whole repo, not just production: neither pairing has a
counterpart in `seed_production.js`, `seed_houston_new.js`,
`set_houston_launch_order.js` (including its `REMOVALS` list) or the
CSVs. The only `Tex-Mex` string in the codebase is on `chi-7` Dove's
Luncheonette, a **Chicago** restaurant.

**What that does and does not establish.** I can prove rows 6 and 7
describe no restaurant in the app or the repo. I cannot prove they
describe no restaurant in Houston. ChòpnBlọk and Roostar are both real
and both absent, so absence from the app is not evidence of invention.
Andrew is the only person who can say whether rows 6 and 7 were
sourced or filled in.

The narrow conclusion: **three of the five held rows are traceable to
a real production restaurant and two are not**, and nothing published
on the site contradicts production.

## Recommendation

Approved by Andrew, and the principle matters more than the action.

**The disqualifier is provenance, not accuracy.** The verification
above found four of seven suspected fabrications to be true. That is
an argument for deleting them, not against it. Nobody at Vouch knows
which of the 40 paragraphs are accurate. A stopped clock is right
twice a day and you still do not use it to tell the time.

Repairing 12 flagged claims inside 40 generated paragraphs leaves 28
paragraphs of unsourced copy that merely have no falsifiable claim in
them yet, plus a maintenance story in which the next person assumes
the surviving text was checked.

**Delete all 40 descriptions and all vibeTags.** Then re-add verified
facts deliberately, one at a time, by a human who checked. Corkscrew's
Michelin star comes back that way, because it is both excellent and
true, and it will be in the app because somebody verified it rather
than because a scaffold guessed right.

Houston is the exception that needs care: it is a launch city whose
content is scaffold. Its 10 descriptions need rewriting rather than
deleting, to the minimal verifiable shape (cuisine, neighbourhood,
service style), with the voice moving into the insider note where
Andrew is the named speaker.

That leaves the product saying only what can be checked, and puts
every subjective claim behind a human who actually went.
