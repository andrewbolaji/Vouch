# Photograph provenance, measured

2026-08-17. Read only, nothing changed, nothing uploaded. This answers
step 0 of `docs/STORAGE_MIGRATION_PLAN.md` with a measurement instead
of a memory test, because asking a person to certify 59 files from
recollection is a test they pass regardless of the truth.

## Method

`exiftool` is not installed on this machine and installing software to
answer a question is a change to the machine, so the metadata was read
directly:

- **PNG**: parse the chunk stream, decode `tEXt`, `zTXt` and `iTXt`,
  and parse any `eXIf` chunk as a TIFF block for Make, Model,
  Software, DateTimeOriginal, lens and GPS.
- **JPEG**: parse APP1 for the same fields, plus XMP.
- Cross-checked against Spotlight (`mdfind`) for finding related files
  elsewhere on the machine.

The script is throwaway and lives in the session scratchpad. Every
number below is reproducible from the files in the repo.

## Result: the three buckets

| Bucket | Count |
|---|---|
| Camera EXIF consistent with a single phone | **0** |
| Metadata from something else | **59** |
| No metadata at all | **0** |

All 59 files in `assets/demo/` carry an Adobe XMP packet, and every one
of them contains exactly three fields:

```xml
<exif:PixelYDimension>1658</exif:PixelYDimension>
<exif:PixelXDimension>1634</exif:PixelXDimension>
<exif:UserComment>Screenshot</exif:UserComment>
```

**59 of 59 carry `UserComment: Screenshot`.** None carries a camera
make, a model, a capture timestamp, a lens, an orientation or GPS.
None carries a creator, a copyright or a rights statement.

**The dimensions corroborate it.** They are all different and all
arbitrary: 528x646, 930x1588, 1254x1662, 1642x1112, 1658x1660. An
uncropped screen capture has one fixed size per device. Fifty-nine
different arbitrary sizes is what cropping produces.

## What this proves, and what it does not

**The measurement succeeded.** The concern going in was that PNG
conversion strips EXIF and a bare set would prove nothing. That is not
what came back: the metadata is present, uniform and affirmative
rather than missing.

**It proves screen capture.** `UserComment: Screenshot` is written by
iOS and macOS when a screen is captured. It is not a thing a camera
writes.

**It does not prove what was on the screen.** A screenshot of Andrew's
own photograph carries exactly the same marker as a screenshot of
somebody else's. The measurement narrows the question sharply; it does
not close it.

## The originals: there are none, and there is a second batch

**No camera originals exist in the project tree.** No HEIC, no DNG,
nothing with a camera signature.

Spotlight, searched by restaurant name, turns up a **separate and
later batch** in `~/Downloads`, named by hand on a consistent scheme,
`{restaurant}_{n}_{dish}.jpg`, dated 2026-08-06 to 2026-08-12:

```
mensho_1_ramen.jpg     mensho_2_uni.jpg      mensho_3_spread.jpg
mensho_4_wagyurice.jpg mensho_5_karaage.jpg  corkscrew_1_meat.jpg
corkscrew_2_cobbler.jpg corkscrew_3_tray.jpg chopnblok_1_stew.jpg
chopnblok_2_suya.jpg   chopnblok_3_drink.jpg
```

Measured:

| | Value |
|---|---|
| Files | 11 |
| Camera EXIF | **none, on any of them** |
| Dimensions | **1080x1350 on every single one** |

1080x1350 is Instagram's 4:5 post size, and Instagram strips EXIF on
upload. Eleven files at exactly that size with no metadata is not what
a camera roll looks like.

These are **not** the sources of the 59 PNGs. Compared by eye,
`assets/demo/Mensho.png` (a matcha-dusted bowl, cropped square) and
`mensho_1_ramen.jpg` (a tonkotsu bowl with eggs, 4:5) are different
photographs. The `~/Downloads` batch is a later, second sourcing pass.

## The finding that changes the question

**`site/img/mensho.jpg` is byte-identical to `~/Downloads/mensho.jpg`**
(same SHA-1), and is a 300x300 crop of `mensho_1_ramen.jpg`, verified
by hash and by eye. The other five site photographs are the same
shape, 300x300 crops from the same workflow.

That file is on vouchfood.com **today**.

So the exposure being weighed for Firebase Storage is not hypothetical
and not in the future. Whatever the answer turns out to be, it applies
retroactively to a live public site, and it applies to the six images
on it before it applies to the 59 in the app. `site/` is out of scope
for this work by standing rule, so this is reported and not touched.

## What Andrew is being asked, and it is a short list

Not "certify 59 files". The measurement has already established that
none of them came off a camera. The questions are:

1. **The six that actually render** (`Mensho`, `Corkscrew BBQ`,
   `Crave Suya`, `Lost and Found`, `Top Sushi`, `The Better Box`):
   what was on the screen when each was captured, and did anyone give
   permission?
2. **The `~/Downloads` batch, and therefore vouchfood.com**: where did
   those eleven come from, and is there permission in writing?
3. **The other 53** can be answered later or deleted unanswered. They
   render nothing today.

Answers go into `docs/PHOTO_MANIFEST.md`, one line per file, so this
is never asked from memory again.

## Recommendation

**Migrate none of them.** Not the six, not the 59. The storage
migration stays blocked at step 0, which is where the plan already put
it, and it is now blocked on a documented fact rather than on an
unanswered question.

If the answer to (1) is that permission does not exist, the right move
is the one this cycle already made with the 33 generated insider
notes: delete the population, and re-add photographs one at a time as
real ones arrive. Houston is already waiting on photographs. Nothing
about that changes except that the wait is now honest.
