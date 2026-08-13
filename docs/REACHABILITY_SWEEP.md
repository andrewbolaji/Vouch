# Reachability sweep, 2026-08-13

Every conditional render path and gated read in `lib/`, answered
against the production data path rather than against a test fixture.

The question for each row is not "does this code exist" but "can this
condition be true for a real user, and which user." Findings 2, 11 and
12 were all the same defect: a branch whose condition cannot be true
in production, passing tests because the test loads data through a
path the real app never uses.

Nothing was fixed during this sweep. Measurement only.

## How reachability was established

Three sources, named per row:

- **prod** — read from `majorcitymusteats` on 2026-08-13 via the
  Admin SDK, read-only.
- **code** — traced from the call site back to the writer or parser.
- **rules** — `firestore.rules`.

Production shape, since most rows depend on it:

```
restaurants: 57
  vibeTags     present 57, non-empty 40
  locations    present 57, non-empty 57
  openingHours present 17
  displayOrder present 27   (houston 10, atlanta 17)
  imageUrl     placeholder:// 27, unsplash 30
  insiderNotes subcollection on 50 of 57
  comments     on 0 of 57
  replies      on 0 comments
  votes        on 0 of 57
users: 4
```

## Unreachable, or reachable only in a state nobody has tested

| # | Path | Condition | Reachable? | For whom | How established |
|---|---|---|---|---|---|
| A | `restaurant_detail_screen.dart:669` | `whatToOrder != null \|\| insiderTip != null` | **No** | Nobody | code. `restaurant_repository.dart:78-79` sets both to `null` on every parse. The gate can never be true, so neither `InsiderNotes` nor its paywall teaser renders for anyone, paid or free. This is finding 2. |
| B | `restaurant_repository.dart:54 getInsiderNotes` | n/a, it is a method | **Never called** | Nobody | code. Zero call sites in `lib/`. Only callers are 3 tests. Meanwhile **prod** holds an `insiderNotes` subcollection on 50 of 57 restaurants. The data exists, the reader exists, the widget exists, and nothing connects them. |
| C | `insider_notes.dart:44` and `:50` | `whatToOrder != null`, `tip != null` | **No** | Nobody | code. Downstream of A. The widget is only constructed at `restaurant_detail_screen.dart:673`, inside the gate that can never be true. |
| D | `home_screen.dart:199` | `!city.isLive` | **Always true** | Everyone | prod + code. `status` absent on 4 cities, `comingSoon` on atlanta; `city.dart:17` defaults absent to `comingSoon`. The inverse branch, a tappable city card, is unreachable. This is finding 12. |
| E | `restaurant_detail_screen.dart:587` | `commentsStatus == CommentLoadStatus.error` | Reachable, **never exercised** | Anyone offline | code. Set only in `AppState`'s catch. No test covers it, and **prod** has 0 comments on 0 restaurants, so no manual pass has ever reached it either. |
| F | `restaurant_detail_screen.dart:613` | `comments.isEmpty` | **Always true today** | Everyone | prod. 0 of 57 restaurants have comments. The non-empty branch, the entire comment list, has never rendered against production data. |
| G | `comment_tile.dart:106` | `replies.isNotEmpty` | **No, today** | Nobody | prod. 0 comments exist, so 0 replies exist. Reply rendering is untested against real data. |
| H | `restaurant_detail_screen.dart:462` | `_replyingToId != null` | Reachable | Any signed-in user | code. Local state, set by tapping Reply. Not data-gated. |
| I | `city_detail_screen.dart:97` | `canViewTop10 && top6to10.isEmpty && isOffline` | Reachable | Entitled user, offline | code. New in `2775761`, covered by a test that drives the real catch branch. |
| J | `restaurant_detail_screen.dart:339` | `membership.canSaveRestaurants` | Reachable | localsPass or cityInsider | code. No data dependency. |
| K | `upgrade_screen.dart:264, :319` | `price != null` | Unknown | Anyone | code. `price` comes from RevenueCat offerings. Not verifiable without a configured store account. **Not measured.** |
| L | `home_screen.dart:147` | `cities.isEmpty && searchQuery non-empty` | Reachable | Anyone searching | code. Client-side filter over 5 cities. |
| M | `restaurant_detail_screen.dart:263` | `vibeTags.isNotEmpty` | Reachable | Everyone | prod. Non-empty on 40 of 57. The empty branch is also real, on the other 17. |
| N | `restaurant_detail_screen.dart:387` | `locations.isNotEmpty` | **Always true** | Everyone | prod. Non-empty on 57 of 57. The empty branch is unreachable, which is harmless but untested. |
| O | `restaurant_image.dart:72` | `demoAsset != null` | Reachable for 6 restaurants | Everyone | prod + code. See below, this one is worse than it looks. |

## The image path, measured

`RestaurantImage.build()` resolves a demo asset by
`restaurant.name.toLowerCase().trim()` against the 29 keys in
`demo_image_overrides.dart`, and falls through to
`CachedNetworkImage(restaurant.imageUrl)` otherwise.

Matched against production:

| | Count |
|---|---|
| demo keys | 29 |
| keys matching a real restaurant name | **6** |
| keys matching nothing in production | **23** |

The 6 that hit: `mensho`, `corkscrew bbq`, `crave suya`,
`lost and found`, `top sushi`, `the better box`.

The 23 dead keys include `blood bros. bbq`, `truth bbq`, `the pit
room`, `hidden omakase`, `march`, and **`chopnblok`**.

That last one is the predicted failure already latent in the file.
The restaurant Andrew intends to add is **ChòpnBlọk**, which
lowercases to `chòpnblọk` and will not match the key `chopnblok`. The
image will silently not resolve, and the fallthrough is
`CachedNetworkImage`, which returns a placeholder rather than an
error. Nothing reports it.

Consequence for the 27 curated (`placeholder://`) documents:

| | Count |
|---|---|
| resolve a demo asset | **6** |
| resolve nothing, so render a grey placeholder | **21** |

The 21 with no image at all today: every one of Atlanta's 17, plus
Houston ranks 2 `Tacos Los Brothers`, 4 `The Peri Peri Factory`, 9
`Joey Uptown`, 10 `Lotus Seafood`.

This corrects a claim in `docs/REMEDIATION_STATE.md`. I wrote that
deleting the demo layer "turns every Houston and Atlanta card grey."
It does not, because 21 of 27 are **already grey**. Deleting the demo
layer costs 6 images, not 27. That makes the Storage migration
cheaper than recorded, and it makes the current state worse than
recorded.

## The pattern

A, B, C, D and finding 11's `List.generate(top6to10.length, ...)` are
one defect in five places: a branch guarded on data that the
production read path cannot supply.

They share a second property, which is why tests did not catch them.
Each one is covered by a test that supplies the data directly, through
a seed list or a fake repository, bypassing the parser or query that
strips it. The test proves the widget renders given the data. Nothing
proved the data arrives.

That is framework sub-point 3e: a citation proves a thing exists, not
that it is reachable.

E, F, G and N are a softer version: reachable in principle, but never
once exercised against real data, because production holds zero
comments, zero replies and zero votes.

## Not measured

- **K**, `price != null` in `upgrade_screen.dart`. Needs a configured
  RevenueCat account and a store connection. Recorded as unknown
  rather than assumed reachable.
- Anything behind `AuthService` beyond the 4 existing users.
- Golden coverage, which runs on CI rather than here.
