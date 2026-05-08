# Vouch -- Session 4 Handoff

**Date:** 2026-05-01
**Baseline:** `flutter analyze` 0 issues |
`flutter test` 100/100 (15s) |
`very_good_analysis` enforced

---

## Deliverable 1: Widget interaction tests

### Test inventory (24 new interaction tests)

| Suite | Tests | Interactions covered |
|---|---|---|
| `test/interactions/home_screen_interaction_test.dart` | 3 | Search filters grid + clearing restores; city tap navigates to CityDetailScreen with correct cityId; profile button navigates to ProfileScreen |
| `test/interactions/city_detail_interaction_test.dart` | 5 | Top 5/10 toggle changes content; paywall gate for free on Top 10; entitled user sees Top 6-10 without paywall; paywall shows upgrade message; restaurant tap navigates to detail |
| `test/interactions/restaurant_detail_interaction_test.dart` | 7 | Vote toggles state + count; save locked triggers upgrade sheet; save toggles for entitled; comment submit clears + shows; reply indicator shows + cancels; insider notes withheld when locked (security); insider notes shown when entitled (security) |
| `test/interactions/profile_screen_interaction_test.dart` | 6 | Sign In navigates; Saved Restaurants navigates; Upgrade Plan opens sheet; Notifications navigates; About opens dialog; suggestion box submits + clears |
| `test/interactions/saved_restaurants_interaction_test.dart` | 3 | Empty state; tap saved restaurant navigates to detail; multiple saved grouped by city |

### Infrastructure changes

- **`test/helpers/test_app.dart`** -- shared `buildTestApp` with `membershipOverride` param and `pumpPastLoad` helper.
- **`MembershipProvider` constructor** -- added `initialTier` named parameter to avoid mock purchase delays in tests. No production behavior change (defaults to `MembershipTier.free`).
- **`mocktail` added** to dev dependencies.

### Full test count

| Category | Tests |
|---|---|
| Provider unit tests | 38 |
| Utility unit tests | 12 |
| Screen smoke tests | 26 |
| Interaction tests | 24 |
| **Total** | **100** |

**Runtime: 15 seconds.** Under 30s ceiling.

### Adversarial passes on test suite

**Taste frame:** All 24 tests test behavior (what
the user sees after an interaction), not
implementation (internal state, widget keys, build
structure). No implementation-coupled tests found.

**Operational frame:** Tests fail loudly on real
bugs -- all assertions expect specific rendered
text content that only appears after successful
data load. `scrollDown` helper uses hardcoded pixel
offsets (moderately fragile but breaks visibly, not
silently).

**Security frame (membership/paywall tests):**
4 tests explicitly verify content absence from the
widget tree, not just visual hiding:
- `insider notes withheld` asserts real tip text is
  `findsNothing` + placeholder is `findsWidgets`
- `paywall gate on Top 10` asserts real restaurant
  name `'Himalaya'` is `findsNothing`
- `entitled user sees Top 6-10` asserts `PaywallGate`
  is `findsNothing`
- `insider notes shown when entitled` asserts
  `InsiderNotes` present + `PaywallGate` absent

---

## Deliverable 2: FIRESTORE_SCHEMA.md

Design doc at project root. Key decisions:

| Decision | Choice | Reasoning |
|---|---|---|
| Region | `us-central1` | Lowest latency to launch markets. Not changeable. |
| `user.savedRestaurantIds` | Array on user doc | Single-read pattern. Atomic `arrayUnion`/`arrayRemove`. Won't hit 1MB at scale. |
| `restaurant.comments` | Subcollection | Unbounded growth. Requires paginated query. |
| `restaurant.votes` | Subcollection (doc ID = user UID) | One-vote-per-user enforced at storage level. Aggregate count denormalized via Cloud Function. |
| Membership gating | Custom claim on auth token + Cloud Function proxy | Rules can read claims without extra reads. Cloud Function strips insider fields for non-entitled users (Firestore has no field-level read rules). |
| Suggestion rate limit | Counter doc + transaction | Atomic read-check-write. No Cloud Function latency. Server-enforced. |

### Cost model (added post-approval)

Added per the review requirement to document the
cost shape of the schema before the first user
lands. Walked through 6 user actions (cold open,
browse city + restaurant, vote, save, comment,
suggestion) with per-action read/write counts.

**Key numbers:**

| Metric | Value |
|---|---|
| Reads per DAU per day | ~145 |
| Writes per DAU per day | ~5 |
| Free tier inflection | ~345 DAU (reads cross 50K/day) |
| Cost at 1K DAU | ~$2.91/month |
| Cost at 10K DAU | ~$28.92/month |
| Dominant cost driver | Document reads (comments pagination: 21 reads per restaurant view) |

**Why this matters:** The schema is correct but the
cost shape wasn't documented. The inflection point
(345 DAU) and the dominant cost driver (comment
reads, not votes or writes) are information needed
before the first billing alert, not after.

Cloud Function invocations (vote aggregation) are
negligible -- well within 2M/month free tier even
at 10K DAU. Writes are cheap ($2.70/month at 10K
DAU). The schema's read-heavy denormalization
strategy is working as designed -- reads dominate
but scale linearly and cheaply.

Three optimization levers documented if cost
becomes a concern: local city caching, reduced
comment page size (20 -> 10), snapshot listeners
instead of cold reads.

Pricing date-stamped May 2026 for auditability.

### Security adversarial pass on schema

| Finding | Severity | Mitigation |
|---|---|---|
| Insider fields on restaurant doc readable by any auth user | High | Cloud Function proxy strips fields. Direct reads blocked by rank-based rule for Top 6-10. |
| `userName` on comment is client-supplied, spoofable | Medium | Rule validates against user doc displayName. |
| `isInsider` on comment is client-supplied | High | Rule validates against `request.auth.token.membershipTier` custom claim. |
| `suggestionCounts` date key is client-supplied, backdatable | Medium | Rule validates against server timestamp. |
| Predictable document IDs enable enumeration | Low | Acceptable. Data is not secret. IDs designed for deep links. |

---

## Production Dart change (1 file)

`MembershipProvider` constructor now accepts
optional `initialTier` parameter. Defaults to
`MembershipTier.free`. Zero behavior change in
production -- existing call sites pass no args.

---

## What's next

`FIRESTORE_SCHEMA.md` is final. `flutterfire
configure` is manual cloud-console work -- not a
Claude Code deliverable. Once the Firebase project
is created and configured, the next code session
wires `kUseFirebase = true` with the schema above.

---

## Verification

```bash
flutter analyze
# Expected: No issues found!

flutter test
# Expected: 100/100 All tests passed!
# Expected runtime: ~15s

dart format . --set-exit-if-changed
# Expected: exit code 0
```
