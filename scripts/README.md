# Seed & maintenance scripts

Admin/maintenance scripts for the Vouch backend. They require Firebase
Application Default Credentials (or `FIRESTORE_EMULATOR_HOST` for local runs).

## Vote data provenance (read this first)

**Vouch launched with zero votes on every restaurant.** Real votes come only
from authenticated users after launch.

- `seed_production.js` and `lib/data/seed_data.dart` seed the real curated
  restaurant lists. Every entry ships with `voteCount: 0`.
- During pre-launch development, a helper (`seed_rank_votes.ts`) generated
  **synthetic** vote documents so the ranking engine had timestamped data to
  exercise. Those synthetic votes existed **only in development / the Firestore
  emulator and were never applied to the production launch.** Earlier commits
  in this repo's history also carried placeholder display counts (roughly
  987–3241) on the demo cities. All of that was zeroed and the seeder retired
  before launch — see `reset_votes.js` and commit `fb19327`. `seed_rank_votes.ts`
  was removed from the working tree and remains only in git history.

If you are reviewing git history and find non-zero vote counts or the retired
seeder, they are synthetic development fixtures, not production data.

## Scripts

- `seed_production.js` — seed the production restaurant lists (voteCount 0).
- `seed_atlanta.js`, `seed_houston.js`, `seed_houston_new.js` — per-city seeds.
- `set_atlanta_launch_order.js`, `set_houston_launch_order.js` — set display order.
- `reset_votes.js` — zero all vote counts and delete every `votes` subcollection
  document. Run with `--confirm` to apply; default is a dry run.
- `backfill_comment_counts.js` — recompute cached comment counts.
