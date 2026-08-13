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

| # | Field | Restaurant | Text | Why it is wrong |
|---|---|---|---|---|
| 1 | `description` | nyc r2 Di Fara Pizza | "**Dom DeMarco has been hand-cutting basil on every slice** since 1965." | Domenico DeMarco died 17 March 2022. Present perfect continuous about a named person, dead four years. Independently verified by Andrew. |
| 2 | `description` | nyc r1 Peter Luger | "**Cash only**, no menu needed. Porterhouse for two since 1887." | Peter Luger began accepting credit cards in 2021, ending a decades-long cash-only policy that was its most repeated trait. A user is told to bring cash for a $200 steak dinner on the basis of a fact that stopped being true five years ago. |
| 3 | `description` | la r1 Guerrilla Tacos | "**Chef Wes Avila** turned a taco cart into an LA institution." | Avila left Guerrilla Tacos around 2020 and has run other kitchens since. The sentence is past tense so it is not strictly false, but it is the only thing said about the restaurant and it names a chef who is not there. |
| 4 | `vibeTags` | 3 restaurants | `"Cash Only"` | Same defect as #2, in a second field. Includes Peter Luger. |

### Needs verification before being called wrong

I am not confident enough to assert these, and guessing here would
repeat the failure being audited.

| # | Field | Restaurant | Claim | Concern |
|---|---|---|---|---|
| 5 | `description` | houston r5 Corkscrew BBQ | "**Michelin-starred in 2024.**" | The Texas Michelin Guide launched in 2024, but I believe barbecue restaurants received Bib Gourmand and Recommended listings rather than stars. If so this is a fabricated award for a real business, which is the most serious category there is. **Check this one first.** |
| 6 | `description` | houston r10 Lotus Seafood | "**Five locations.**" | A count that drifts. Lotus Seafood has been expanding. |
| 7 | `description` | houston r4 The Peri Peri Factory | "**Houston's first.**" | Unsourced superlative. |
| 8 | `description` | houston r1 Mensho | "**Michelin-recognized.**" | Vague enough to be unfalsifiable, which is its own problem. |
| 9 | `description` | la r8 Petit Trois | "**no-reservations** French bistro. **25 seats.**" | Both are specific operational facts that change. |
| 10 | `description` | la r4 Jitlada | "**Jonathan Gold approved.**" | Gold died in 2018. Historically true, he championed Jitlada, but presented as a live endorsement. Same shape as #1, milder. |
| 11 | `description` | houston r6 Lost and Found | "a **famous Travis Scott mural**." | Named person, specific claim, unsourced. This is also the description that `hou-4`'s deleted insider tip was paraphrased from. |

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

## Recommendation

This matches where Andrew said it was heading, and the data supports it.

The scaffold cities are not curated, are not live, and their content
is generated end to end. **Delete all 40 descriptions and all
vibeTags** rather than repairing 12 flagged claims inside 40 fabricated
paragraphs. Repairing them would leave 28 paragraphs of unsourced
marketing copy that merely have no falsifiable claim in them yet.

Houston is the exception that needs care: it is a launch city whose
content is scaffold. Its 10 descriptions need rewriting rather than
deleting, to the minimal verifiable shape (cuisine, neighbourhood,
service style), with the voice moving into the insider note where
Andrew is the named speaker.

That leaves the product saying only what can be checked, and puts
every subjective claim behind a human who actually went.
