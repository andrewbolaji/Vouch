# Vouch -- Wishlist

Every "good idea but not now" with reasoning and a tier. Items 6+ months old with no customer pull get deleted.

## Governing rule

A restaurant can enhance its listing, never buy its rank. Rankings stay fully local-vote-driven and uninfluenceable by restaurants or by us. Everything monetizable lives outside the ranking. Free food is fine, free rank is not.

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

### Vote weight repositioning + transparency display
**The idea:** Reposition premium tiers around vote weight as the headline feature: Free = 1x, Locals Pass = 3x, City Insider = 3x with insider tips and verified-visit badge. Add vote breakdown display on every restaurant detail page showing total votes, breakdown by tier, and weighted total (e.g., "142 free votes (worth 142) + 15 premium votes (worth 45) = 187 weighted"). Visible to all users including free. Transparency is the ethical defense.

**Why v1.1:** Requires sufficient voting volume for weight to demonstrably move rankings. Launching with this before volume exists makes the feature feel hollow.

**Trigger:** 6+ months post-launch AND voting volume sufficient that vote weight demonstrably moves rankings (estimated 1K+ DAU per active city).

**Effort estimate:** Medium (schema changes to vote docs, Cloud Function for weighted tallying, UI for breakdown display).

---

### Folder restructure (feature-first)
**The idea:** Reorganize lib/ from flat structure (screens/, widgets/, providers/, services/) to feature-first (features/city/, features/restaurant/, features/auth/, etc.).

**Why v1.1:** At 42 .dart files the flat structure is still navigable. The restructure is a rename-heavy diff that adds no functionality and complicates git blame. Cost-benefit flips at ~60 files.

**Trigger:** File count crosses 60 OR a new feature domain is added (e.g., features/map/, features/social/), whichever first.

**Effort estimate:** Small (1 session). Mechanical renames.

---

### User-uploaded restaurant photos
**The idea:** Let signed-in users upload photos at a restaurant. Firebase Storage, upload UI, image resizing, terms-of-use license clause, and a report/takedown flow (shared with comment moderation). Users own their photos; the terms grant a display license.

**Why v1.1:** Produces zero photos with zero users, so it cannot supply launch photos (the permission campaign does that). Build the foundation now (photo data model, storage path, terms language, report/takedown) so the upload UI is a drop-in; ship user-facing upload right after launch once there is a base to generate content.

**Trigger:** First real users are active AND the permission-campaign launch photo set is in.

---

### Restaurant photo gallery (multiple photos per place)
**The idea:** Detail page shows more than one photo in a swipeable hero carousel with page dots; the card uses the primary photo. Food leads, interior and others follow. Handles one photo (no carousel) or many.

**Why v1.1:** Pairs with user photo upload (also v1.1). Once there is more than one image per place, a single-image hero wastes good content. Standard, bounded pattern. Also lets the food-plus-interior shots gathered for the demo be used for real.

**Trigger:** Photo upload ships, or 2+ approved photos exist for a meaningful number of places.

---

### Interactive engagement prompts (content-generation engine)
**The idea:** After a user views or saves a place, prompt them with light questions: "Have you been here?", "What did you order?", "Your thoughts?" Responses feed directly into insider content for the City Insider tier and surface lesser-known spots that would otherwise stay buried.

**Why v1.1:** Strong candidate because it doubles as a content-generation engine, not just engagement. The City Insider tier needs real insider tips and ordering advice to justify its price. User-generated answers are the scalable source. Without this, insider content stays editorial-only and does not grow with the user base.

**Trigger:** City Insider tier is live and needs content beyond editorial seed data, OR user engagement metrics show users browse but do not interact.

**Effort estimate:** Medium (prompt UI, response storage in Firestore, moderation queue integration, insider content surfacing pipeline).

---

## v2 candidates (pin, don't build)

### Owner-claimed listing with the dish to order
**The idea:** A verified owner can claim their spot, confirm details, and pick the one signature dish they would put their name on. Shown next to what locals actually vote for, so the owner's pick and the crowd's pick sit side by side. When they disagree (owner says brisket, locals say boudin), that tension is the brand.

**Why pin, not build:** Needs owner verification, a claim flow, and a moderation surface. Worth it only once there is restaurant interest to engage. Owners never touch rank.

**Trigger:** Owners start asking to claim or correct their listing, or you enter a city with engaged owners to activate.

---

### Earned "Top 10 on Vouch" badge + window decal
**The idea:** A place that earns a Top 10 spot purely from local votes gets a digital badge (shareable, screenshottable) and, for qualifying places, a physical window cling. Earned, never bought. Doubles as guerrilla marketing: every sticker says "locals voted us," not "we advertise here."

**Why pin, not build:** Depends on the ranking engine existing and on rankings being stable enough to define a fair tenure rule.

**Open question to settle first:** How volatile is the Top 10, and how long must a place hold a spot to earn the badge? Likely answer: rank on a rolling window with a stable cadence, award for holding Top 10 across N consecutive periods, not one snapshot. This should inform the ranking engine design (windowing and smoothing), so raise it when that Block is planned.

**Trigger:** Ranking engine shipped and a tenure rule defined.

---

### Restaurant lifecycle management
**The idea:** Vote decay (weighting recent votes higher) + Google Places API weekly verification for operational status and address changes (not user-reported corrections, those add moderation surface we are avoiding for v1). Closed restaurants stay listed but flagged as closed (do not scrub, keeps food memory of cities).

**Why pin, not build:** Requires operational maturity and real data. Premature with seed data.

**Trigger to promote:** 3+ cities live OR 200+ restaurants OR first "restaurant was closed" user complaint.

---

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

### AI query layer
**The idea:** Natural language queries against restaurant and vote data ("best Thai in Houston this month").

**Why v3+:** Needs scale, rich data, and operational maturity. Foundation work (structured data, good schema, denormalized fields) is already in place.

**Trigger to promote:** When v2 metrics dashboard exists and 6+ months of data per city.

---

## Business tier candidates

### Rank-independent restaurant deals
**The idea:** A restaurant offers a small perk to Vouch users (a freebie, a happy hour, "show this screen"), in a separate, clearly labeled surface, available to any place regardless of rank. Drives foot traffic, gives users a reason to keep and upgrade, and is a potential B2B revenue line.

**Why pin, not build:** Andrew wants more discussion before committing. The hard part is the firewall: it works only if it is obviously walled off from rank and not pay-to-play, or it becomes the exact thing Vouch replaces.

**Trigger:** Enough users in a city that foot-traffic offers attract restaurants, plus an agreed labeling and firewall design.

---

## Go-to-market notes (not features)

**Founder and partner photographer program:** On entering a new city, shoot the top spots for seed content and build relationships before launch. The restaurant gets free pro food photos, Vouch gets authentic content. Belongs in the launch playbook, not the feature wishlist. Captured here so it is not lost.

---

## Skipped (deliberately not building)

(None yet. Add items here with reasoning when ideas come up that don't fit the product vision.)
