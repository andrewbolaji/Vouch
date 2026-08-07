# Seed & maintenance scripts

Admin/maintenance scripts for the Vouch backend. They require Firebase
Application Default Credentials (or `FIRESTORE_EMULATOR_HOST` for local runs).

## Vote data provenance (read this first)

**Vouch ships with zero votes on every restaurant.** It has not launched.
Real votes come only from authenticated users after launch.

- `seed_production.js` and `lib/data/seed_data.dart` seed the real curated
  restaurant lists. Every entry ships with `voteCount: 0`.
- During pre-launch development, a helper (`seed_rank_votes.ts`) generated
  **synthetic** vote documents so the ranking engine had timestamped data to
  exercise.

**This section previously claimed those synthetic votes existed only in
development / the Firestore emulator, were never applied to production, and
were cleaned up before launch by `reset_votes.js` and commit `fb19327`. That
was false.** On 2026-08-07, a direct query against the live
`majorcitymusteats` Firestore project (prompted by an unrelated audit of
`votes.createdAt`) found 163 of these synthetic vote documents still present
in production, under 7 restaurant IDs: `hou-2`, `hou-3`, `hou-5`, `hou-6`,
`hou-7`, `hou-8`, `hou-10`. All 7 of those restaurant IDs are themselves
absent from the current restaurants collection — they belong to a retired ID
scheme from before the current `seed_production.js` lineup. Whatever
`reset_votes.js`/`fb19327` actually cleaned up, it did not reach this data.

Every one of the 163 was confirmed synthetic first: a `seed-{restaurantId}-NNN`
document ID, not a real user UID, under a restaurant ID that no longer exists.
The exact 163 document paths were listed and approved before anything was
touched. They were then deleted one path at a time from that explicit list,
not with `reset_votes.js` and not by any prefix or collection-group query, so
the deletion could not reach anything beyond what was approved. A follow-up
query on 2026-08-07 confirmed zero vote documents remained anywhere in the
project, and confirmed nothing outside the 163 approved paths had been
touched.

### How to verify this yourself

Don't take this file's word for it. Run:

```
node scripts/check_vote_timestamps.js
```

It queries every vote document in the project and compares its `createdAt`
field against Firestore's own record of when the document was actually
created, flagging anything that disagrees. The 163 documents above are
exactly what this script would have caught, had anyone run it sooner. If it
reports zero mismatches, believe the script, not this paragraph.

Verified on 2026-08-07: run for real against `majorcitymusteats` (ADC via
`gcloud auth application-default login`, project explicitly pinned since
ambient project detection printed `(unknown)` and could not be trusted until
that was fixed), confirmed it correctly flags a mismatch by seeding one test
vote with a deliberately wrong `createdAt` and watching the script catch it,
then confirmed it reports zero against the real, now-empty `votes`
collection group. Output:

```
Checking vote document timestamps
Target project: majorcitymusteats

Total vote documents: 0

Mismatched (missing or drifted more than 60000ms): 0
```

If you are reviewing git history and find non-zero vote counts or the retired
seeder, they are synthetic development fixtures, not production data as of
this writing. Verify that against a live query, not against this document.
It was wrong about that once already.

## Scripts

- `seed_production.js` — seed the production restaurant lists (voteCount 0).
- `seed_atlanta.js`, `seed_houston.js`, `seed_houston_new.js` — per-city seeds.
- `set_atlanta_launch_order.js`, `set_houston_launch_order.js` — set display order.
- `reset_votes.js` — zero all vote counts and delete every `votes` subcollection
  document. Run with `--confirm` to apply; default is a dry run.
- `backfill_comment_counts.js` — recompute cached comment counts.
- `check_vote_timestamps.js` — flag any vote document whose `createdAt` field
  disagrees with when Firestore actually created it. Read-only.
