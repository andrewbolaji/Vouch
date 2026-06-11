# Vouch Team Handbook

Internal reference for how the app's systems work. Written for the team: enough context to understand the behavior, enough technical detail to debug or extend it. For user-facing documentation, see [USER_GUIDE.md](USER_GUIDE.md).

---

## Rankings

**What it does.** Each city's restaurants are ordered by local votes. The order is recomputed once a day, and recent votes count more than older ones, so the list reflects current local opinion rather than all-time totals.

**How to use it.**

1. Open a city to see its ranked list: Top 5 for everyone, Top 10 for Locals Pass and City Insider members.
2. Open a restaurant and tap the vote button to add a vote. Voting requires sign-in; tapping while signed out opens the sign-in screen.
3. The vote count updates immediately; the restaurant's rank position updates in the next daily recompute.

**Behind the scenes.**

- A scheduled Cloud Function (`recomputeRanks`) runs daily at 6 AM UTC. For each restaurant it reads the vote records, applies exponential time-decay with a 90-day half-life to each vote, sums the weighted decayed values into a `rankScore`, sorts the city's restaurants by that score, and writes a contiguous rank (1 to N) plus the `rankScore` to each restaurant doc.
- The score math lives in a pure module (`rank_engine.ts`) so it is testable without the database; the orchestrator (`rank_recompute.ts`) does the Firestore reads and writes.
- Each vote is one document per user per restaurant (doc id is the user's UID), which guarantees one vote per person. Each vote carries a `weight`, always 1 for now; the security rules reject any other value until verified-visit weighting ships.
- The large vote number shown in the app (`voteCount`) is a separate display counter. The ranking engine ignores it and uses the underlying vote records and their ages.
- A new city is seeded with a modest set of real vote documents dated over the prior weeks, so the engine has something to rank on day one. Those seed votes decay away over months as real votes take over.

**Limits and gotchas.**

- Ranks update at most once a day (overnight in the US), not in real time. A vote shows in the count immediately but moves the rank only at the next recompute.
- One vote per person per restaurant, tied to the account, not the device.
- Verified-visit 2x weighting is built structurally (the `weight` field) but not active; every vote counts equally for now.
- If the daily recompute runs for a city with no vote records yet (for example before the seed migration), every restaurant scores zero and the order falls back to the cosmetic `voteCount`, which reproduces the editorial order.

**Where it shows up.**

- The Top 5 and Top 10 lists on the city screen.
- The rank badge on each restaurant card and detail page.
- The free and paid gate reads the rank: free users see ranks 1 through 5, members see 1 through 10.

<!-- TODO: screenshot of a city's ranked restaurant list -->

---

*Last updated: Ranking Engine Block (2026-06-11).*
