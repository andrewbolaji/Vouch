# Image pipeline: the Firebase Storage migration, for approval

Written 2026-08-16. Nothing here has been run. The standing rule is
that this plan goes to Andrew before it does, including what
`RestaurantImage` becomes and its loading and failure states.

## What this actually buys, stated first because it is less than it sounds

The deadlock is real: photographs render only through the demo layer,
the demo layer cannot ship, and deleting it is the pre-launch
checklist. Storage is the exit.

But the reachability sweep already corrected the size of the prize.
Of 29 demo keys, **6** match a real restaurant. So:

| | Count |
|---|---|
| Curated documents (`placeholder://`) | 27 |
| Rendering a photograph today | **6** |
| Rendering a grey box today | **21** |

**This migration moves 6 photographs and changes the plumbing.** It
does not give Houston a photographed Top 10, and no amount of
engineering will: 4 of Houston's 10 and all 17 of Atlanta's have no
photograph in the repo at all. Houston stays unpublished until Andrew
shoots them either way. Worth doing anyway, because the plumbing is
what lets a photograph appear the day it exists, and because the demo
layer is currently leaking gated names and images into the binary.

## Blocking question, and it is not a technical one

**Where did the 59 photographs in `assets/demo/` come from?**

Nothing in the repo records it. This cycle has already deleted 33
insider notes on provenance rather than on accuracy, and the same
question applies harder here, because the migration changes what is
being claimed. A photograph bundled inside a private demo build is a
small exposure. The same file uploaded to the project's own bucket
and served as the app's content is a public act of publishing.

Three cases, and only Andrew knows which:

1. **Andrew took them.** Migrate all of them, no further question.
2. **Supplied by the restaurant** (press kit, their own social
   account, permission given). Migrate, and record who gave what,
   because the record is the defence.
3. **Downloaded from Google Maps, Yelp, Instagram or a review site.**
   Do not migrate. They are somebody else's copyright, and serving
   them from the app's own bucket next to a paywall is the worst
   version of that.

If the answer is mixed, it has to be per file, and the six that
actually resolve today are the only ones that matter for launch:
`mensho`, `corkscrew bbq`, `crave suya`, `lost and found`,
`top sushi`, `the better box`.

**Nothing else in this plan should run until that is answered.**

## Second fact that shapes everything: the files are the wrong shape

Measured, not assumed:

| | Value |
|---|---|
| `assets/demo/` total | **175 MB** |
| Files | 59 |
| Average | ~3 MB |
| Format | PNG |
| Typical dimensions | ~1600 x 1650 |

A 5 MB PNG is not a photograph for a phone, it is a screenshot of one.
Re-encoded at quality 80, measured on three of them:

| File | PNG | JPEG, 1600px | JPEG, 800px |
|---|---|---|---|
| `Mensho.png` | 5,100 KB | 840 KB | 288 KB |
| `Corkscrew BBQ entrance.png` | 5,716 KB | 836 KB | 280 KB |
| `Cool Runnings.png` | 4,248 KB | 520 KB | 200 KB |

Roughly 7x smaller at hero size and 20x at card size, with no visible
loss at either. **The processing step is not an optimisation, it is
part of the migration.** Uploading the PNGs as they are would put
about 175 MB in the bucket and push 3 MB down a phone connection to
draw a card the size of a business card.

Two renditions per image, because the app already has two uses: the
card (`RestaurantImage`, small) and the detail hero
(`restaurant_detail_hero.dart`, full width, and it splits into two
panes when a second image exists).

## Cost, in units rather than dollars

Read the current unit prices off the console; what follows is the
arithmetic to apply them to, which is the part that does not change.

**Storage.** 6 restaurants x 2 renditions x ~0.5 MB average is about
**6 MB**. If Andrew shoots all 27 curated restaurants with a second
image each: 27 x 2 x 0.5 MB is about **27 MB**. This is a rounding
error against any free tier and will stay one.

**Egress, which is the part that scales with success.** Cached by
`cached_network_image` after first fetch, so the unit is one fetch per
image per device, not per screen open.

| Action | Images | Bytes |
|---|---|---|
| First open of a city screen | 5 cards | ~1.3 MB |
| Opening one restaurant | 1 hero (2 if split) | ~0.8 to 1.6 MB |
| A user who browses all 10 and opens 3 | 10 + 4 | ~5.5 MB |

So roughly **5 MB per engaged new user, once**. At 1,000 installs
that is about 5 GB of egress in total, not per month. The number that
would change this is a redesign that loads hero-sized images into
cards, which is why the two renditions exist.

## The design

### 1. Storage layout, keyed by id

```
restaurants/{restaurantId}/{n}-card.jpg      800px longest side
restaurants/{restaurantId}/{n}-hero.jpg     1600px longest side
```

`n` is 0-based position, so 0 is the primary. Keyed by document id and
never by name, which is the agreed constraint and the lesson of
`chopnblok` versus `chòpnblọk`: a name lookup that misses returns
nothing, nothing is a valid state, and the failure never reports
itself.

### 2. URLs are written by the script and read as plain strings

Upload with an explicit `firebaseStorageDownloadTokens` metadata value
so the download URL is deterministic and the script owns it:

```
https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<url-encoded path>?alt=media&token=<uuid>
```

Consequences, all of them good here:

- **No `firebase_storage` dependency in the app.** The URL is a plain
  string and `cached_network_image` already handles it. One fewer
  plugin in a binary that has to be rebuilt for iOS.
- **Storage rules can deny clients outright** (`allow read, write: if
  false`), because a token URL is a capability and does not consult
  rules. Nothing in the app talks to Storage directly.
- **Rotating a token invalidates a URL**, which is the recovery path
  if an image ever has to be pulled: rotate, re-run, done.

`storage.rules` does not exist and `firebase.json` has no `storage`
section, so provisioning the bucket and adding both is part of step 0.

### 3. The document field, and deliberately not two of them

Replace `imageUrl` with `imageUrls: List<String>` in the same commit
rather than adding the second field alongside the first.

`Restaurant.imageUrl` is a required single string, and the hero
already wants two. Keeping both would mean two sources of truth for
the same question, which is precisely the shape of every drifting
denormalisation this cycle has had to unpick (`restaurantCount`,
`voteCount`, comment `userName`). One field, ordered, primary first,
empty list meaning no photograph.

The 30 `images.unsplash.com` rows are deleted rather than migrated, as
already approved: stock photographs standing in for specific real
restaurants' food, in cities that are not live.

### 4. What `RestaurantImage` becomes

Today it has two visual states and three real ones. `_placeholder()`
(grey) is shown while loading, and `_placeholderWithIcon()` (grey plus
a fork) on network error.

**A restaurant with no photograph does not reach either state
honestly.** Measured with a throwaway widget test against a document
carrying `placeholder://restaurant` and no demo match: after two
seconds of pumped time the error widget has not appeared, icon count
0, so what renders is the loading grey. Not conclusive for a real
device, since the failure arrives through `flutter_cache_manager` and
a headless run is not a network stack, and it does not need to be:
either way 21 documents draw an undifferentiated grey rectangle, and
neither of the two states it could be in is the true one.

Three states, distinguished:

| State | Today | Proposed |
|---|---|---|
| Loading | grey box | shimmer (`shimmer` is already a dependency) |
| Failed | grey + fork icon | unchanged, plus a retry on the detail hero |
| **No photograph** | grey box forever | a designed empty state, quiet and deliberate, not an error |

The third is the one that matters, because at launch it is the
common case rather than the exception, and "no photograph yet" and
"this failed to load" are different sentences.

### 5. The script

`scripts/migrate_images_to_storage.js`, following the shape of
`scripts/publish_city.js` and testable the way
`scripts/test/city_publisher.test.js` is.

- **An explicit mapping file**, restaurant id to source filenames, in
  the repo and reviewed by eye. Not derived from filenames, not
  matched on names. 6 entries today.
- **`--dry-run` by default.** Prints what it would upload and write,
  touches nothing.
- **Idempotent.** Re-running overwrites the same object paths and
  writes the same URLs. Safe to run twice.
- **Read-back verification**, in the script and reported: every URL it
  wrote fetched once, expecting 200 and a JPEG content type. A URL
  written but not fetchable is the exact failure this pipeline is
  prone to, and it is invisible from Firestore.
- **A closing report of what has no image**, by name, so the gap is a
  list rather than a feeling.

### 6. Deletion, in the same commit

`lib/config/demo_image_overrides.dart`, `assets/demo/`, the
`pubspec.yaml` assets entry, `resolveDemoAsset`, `resolveImageSources`
and the `ImageSource` class. Not deprecated, not flag-flipped. Half a
migration leaves two lookup paths and the binary leak stays open.

Then re-run finding 4's measurement, which is the point of doing it
this way:

| Canary | Before | Expected after |
|---|---|---|
| `Top Sushi` | 1 | **0** |
| `The Better Box` | 1 | **0** |
| `Mensho` (control) | 3 | 3 |
| `Corkscrew BBQ` (control) | 3 | 3 |

That takes finding 4 from 5 of 7 canaries to 7 of 7, and it is the
only thing that closes the second leak channel documented in
`IMPLEMENTATION_RATIONALE.md`.

## Order of operations

| # | Step | Needs |
|---|---|---|
| 0 | Answer the provenance question | **Andrew** |
| 1 | Provision Storage, add `storage.rules` and the `firebase.json` section | Andrew's console, then code |
| 2 | Processing and upload script, dry-run only, with its test | code |
| 3 | Run for real against the 6, verify by read-back | code |
| 4 | `imageUrls` on the model, `RestaurantImage`'s three states, demo layer deleted, Unsplash URLs dropped, all one commit | code |
| 5 | Re-run the `strings` grep, publish the 7 of 7 table | code |
| 6 | Andrew's photographs land the same way, script re-run per batch | **Andrew** |

Steps 2 to 5 are about a day. Step 0 is a question and step 6 is a
camera, and those are the ones the schedule actually depends on.

## What could go wrong that this plan does not cover

- **The 6 photographs may not be the right 6.** They match on name
  today; nobody has checked that the photograph is of that restaurant
  and not of a dish that resembles it. Worth one look before upload,
  since the provenance conversation is happening anyway.
- **Bucket location.** Firestore is `us-central1`; the bucket should
  match, and it cannot be changed afterwards.
- **Nothing here touches `site/`**, which serves its own images from
  `site/img/` and is out of scope by standing rule.
