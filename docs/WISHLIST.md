# Vouch -- Wishlist

Every "good idea but not now" with reasoning and a tier. Items 6+ months old with no customer pull get deleted.

---

## v1.1 (committed for build)

### Riverpod migration
**The idea:** Replace Provider with Riverpod across all 4 providers. Eliminates BuildContext coupling, makes testing easier, enables non-widget context access.

**Why v1.1:** Provider works fine at current scale. Migration is mechanical but touches every screen. Interaction tests (24 tests, all passing) provide the safety net. Trigger already fired.

**Trigger:** Widget interaction tests pass. (Complete as of Session 4.)

**Effort estimate:** Medium (5 sessions, 1 provider per session, start with SavedProvider).

---

### go_router with typed routes
**The idea:** Replace Navigator.push(MaterialPageRoute(...)) with go_router for declarative routing and deep link support (vouch.app/city/houston/restaurant/hou-1).

**Why v1.1:** Current navigation works but cannot handle incoming deep links. Required for the share/deep-link feature.

**Trigger:** Share feature work begins, OR deep links get prioritized in product roadmap.

**Effort estimate:** Small (1 session). Define route tree, replace all Navigator.push calls, add go_router_builder for type safety.

---

### freezed + json_serializable models
**The idea:** Replace hand-written models with freezed for ==, hashCode, complete copyWith, and fromJson/toJson.

**Why v1.1:** Hand-written models work for seed data but cannot serialize to/from Firestore without fromJson/toJson. Current copyWith is partial (not all fields).

**Trigger:** Firebase data layer is wired (kUseFirebase = true), requiring Firestore serialization.

**Effort estimate:** Small (1 session, 5 model files + build_runner setup).

---

### In-app password reset deep link handling
**The idea:** Handle the Firebase password reset email deep link inside the app instead of opening the default Firebase web handler.

**Why v1.1:** Requires go_router for deep link routing. Firebase's default web handler works for v1.

**Trigger:** When go_router ships.

**Effort estimate:** Small (part of the go_router session).

---

### Folder restructure (feature-first)
**The idea:** Reorganize lib/ from flat structure (screens/, widgets/, providers/, services/) to feature-first (features/city/, features/restaurant/, features/auth/, etc.).

**Why v1.1:** At 42 .dart files the flat structure is still navigable. The restructure is a rename-heavy diff that adds no functionality and complicates git blame. Cost-benefit flips at ~60 files.

**Trigger:** File count crosses 60 OR a new feature domain is added (e.g., features/map/, features/social/), whichever first.

**Effort estimate:** Small (1 session). Mechanical renames.

---

## v2 candidates (pin, don't build)

### Operations metrics dashboard
**The idea:** Surface data over time: vote trends per city, comment frequency, suggestion patterns, user retention signals.

**Why pin, not build:** Need real usage data before this is meaningful. Foundation for potential AI-powered insights layer.

**Trigger to promote:** When 3+ months of real user data exists and at least 500 DAU sustained.

---

### All-time vs windowed vote counts
**The idea:** Track weekly/monthly vote windows for trending restaurants, not just all-time counts.

**Why pin, not build:** Requires votesThisWeek field + scheduled Cloud Function reset. Adds schema complexity. Not needed until real voting patterns emerge and stale rankings become a user problem.

**Trigger to promote:** When vote data shows stale rankings (same Top 5 for 3+ months despite active voting).

---

### Comment editing
**The idea:** Allow users to edit comments within a time window (15 minutes after posting).

**Why pin, not build:** Adds updatedAt field and time-windowed update rule. Low priority vs core features shipping.

**Trigger to promote:** When 3+ users have asked for it.

---

### Email link / passwordless sign-in
**The idea:** Add email magic link as a sign-in option, removing the password step entirely.

**Why pin, not build:** Google and Apple sign-in already solve the password-averse use case. Email link requires deep-link infrastructure (go_router), which is itself deferred. Not worth the complexity until there's evidence users are dropping off at the password field.

**Trigger to promote:** go_router ships AND password-fatigue feedback from real users.

---

### Suggestion daily cap: UTC alignment
**The idea:** Switch suggestion rate-limit date key from local time to UTC, matching server-side enforcement.

**Why pin, not build:** Client-side cap is UX only (not security). Local time is fine for a local-only prototype. Server uses UTC; client should match to avoid timezone/midnight boundary double-counting.

**Trigger to promote:** Firebase is live and suggestion cap is server-enforced.

---

### User-visible persistence error feedback
**The idea:** SnackBar feedback and retry logic when Firestore writes fail (network, permissions, quota).

**Why pin, not build:** SharedPreferences on device storage has near-zero failure rate. Current fallback is debugPrint and silent continuation. Only matters when writes go over the network.

**Trigger to promote:** Firebase is live and real write failures are possible.

---

### Reconcile cost model against Firebase Console actuals
**The idea:** Compare FIRESTORE_SCHEMA.md cost estimates (~145 reads, ~5 writes per DAU per day) against real Firebase Console billing. Validate the 345-DAU free-tier inflection point. Adjust comment page size or caching strategy if reads are higher than projected.

**Why pin, not build:** No real users yet. Cost models are living documents updated against real telemetry, not estimates frozen at design time.

**Trigger to promote:** 30 days after first 100 DAU sustained.

---

## v3+ candidates (further out)

### User-uploaded restaurant photos
**The idea:** Photos subcollection with Firebase Storage references and moderation status.

**Why v3+:** Requires content moderation pipeline (manual or automated). Unsplash URLs work for v1. User photos add liability without moderation.

**Trigger to promote:** When community engagement is strong enough to self-moderate, or when a moderation service is integrated.

---

### AI query layer
**The idea:** Natural language queries against restaurant and vote data ("best Thai in Houston this month").

**Why v3+:** Needs scale, rich data, and operational maturity. Foundation work (structured data, good schema, denormalized fields) is already in place.

**Trigger to promote:** When v2 metrics dashboard exists and 6+ months of data per city.

---

## Business tier candidates

(None yet. Add pricing, packaging, and business model items here as they come up.)

---

## Skipped (deliberately not building)

(None yet. Add items here with reasoning when ideas come up that don't fit the product vision.)
