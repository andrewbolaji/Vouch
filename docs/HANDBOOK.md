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
- Verified-visit 3x weighting is built structurally (the `weight` field) but not active; every vote counts equally for now.
- If the daily recompute runs for a city with no vote records yet (for example before the seed migration), every restaurant scores zero and the order falls back to the cosmetic `voteCount`, which reproduces the editorial order.

**Where it shows up.**

- The Top 5 and Top 10 lists on the city screen.
- The rank badge on each restaurant card and detail page.
- The free and paid gate reads the rank: free users see ranks 1 through 5, members see 1 through 10.

<!-- TODO: screenshot of a city's ranked restaurant list -->

---

## Comments

**What it does.** Users can post comments on any restaurant and reply to existing comments, creating threaded conversations. City Insider members get a visible "Insider" badge on their comments.

**How to use it.**

1. Open a restaurant's detail page and scroll to the Comments section.
2. Type a comment (up to 500 characters) and tap the send button.
3. To reply, tap "Reply" on an existing comment. A banner shows who you are replying to; type your reply and tap send. Tap the X on the banner to cancel.
4. On other users' comments, tap the three-dot menu for "Report comment" or "Block this user" (see Comment Moderation below).

**Behind the scenes.**

- Comments are stored as a subcollection at `/restaurants/{restaurantId}/comments/{commentId}`. Each document holds `userId`, `userName`, `text`, `createdAt`, `parentId` (null for top-level comments, the parent comment ID for replies), and `isInsider` (boolean).
- The `isInsider` flag is enforced by Firestore security rules: the create rule checks `request.resource.data.isInsider == (request.auth.token.membershipTier == 'cityInsider')`, so only actual City Insiders can set it to true.
- The `userName` field is also rule-enforced: it must match the `displayName` on the user's `/users/{uid}` doc, preventing impersonation.
- Top-level comments are sorted newest-first (`createdAt` descending). Replies within a thread are sorted oldest-first (`createdAt` ascending) so conversations read top-to-bottom.
- When a user deletes their account, their comments are anonymized (userId set to `"deleted"`, userName set to `"Deleted user"`, isInsider set to false) rather than deleted. This preserves reply threads. See Account Deletion below.
- Security rules allow create and delete (own comments only), but no updates. There is no edit-comment feature.

**Limits and gotchas.**

- 500-character maximum, enforced by both the client TextField and the security rules.
- Comments cannot be edited after posting, only deleted by the author.
- The insider badge reflects the user's tier at the time of posting. If they downgrade later, existing comments keep the badge because the stored `isInsider` field is immutable.

**Where it shows up.**

- The Comments section on each restaurant detail page.
- The insider badge appears inline next to the commenter's name.

<!-- TODO: screenshot of a comment thread with an insider badge -->

---

## Comment Moderation (Report and Block)

**What it does.** Users can report comments for review and block other users so their comments are hidden. This exists for App Store Guideline 1.2 (user-generated content).

**How to use it.**

1. On any comment that is not your own, tap the three-dot menu.
2. Tap "Report comment" to open a reason picker (Spam or advertising, Harassment or bullying, Inappropriate content, Something else). Pick a reason and the report is submitted.
3. Tap "Block this user" to immediately hide all of that user's comments from your view.

**Behind the scenes.**

- Reports write to the `/reports` collection. Each report stores `reporterUid`, `commentId`, `commentPath`, `restaurantId`, `cityId`, `reason`, and `createdAt`. Reports queue for manual admin review in the Firebase console. There is no auto-hide or auto-removal.
- The report rate limit is 5 per day (`kDailyReportCap`). This limit is client-side only, enforced by `ReportProvider` checking `/users/{uid}/reportCounts/{dateKey}`. The security rules validate field types and require `reporterUid == auth.uid`, but do not check the count. This is acceptable because reports are low-value writes that queue for review; if abuse becomes real, a Cloud Function gate can be added (matching the suggestion pattern).
- Blocking is client-side filtering. The blocked user IDs are stored at `/users/{uid}` (managed by `UserRepository.addBlock`/`removeBlock`). On sign-in, the restaurant detail screen loads the blocklist via `getBlockedIds`. The single source of truth for filtering is `filterBlockedComments()` in `lib/core/utils/block_filter.dart`, which removes comments whose `userId` is in the blocked set.
- Firestore cannot efficiently exclude a dynamic list of user IDs in a query, so block filtering happens after the read, before rendering.

**Limits and gotchas.**

- Reporting does not hide the comment. It only queues it for admin review.
- The report rate limit is client-side, not tamper-proof. See DECISIONS.md for the reasoning.
- The block list is per-device-session until sign-in syncs it. Blocked users can be managed from the Blocked Users screen in Profile.

**Where it shows up.**

- The three-dot menu on each non-own comment in the restaurant detail screen.
- The Blocked Users list in Profile settings.

<!-- TODO: screenshot of the report reason picker -->

---

## Account Deletion

**What it does.** A signed-in user can permanently delete their account and all associated data from the Profile screen. Required by App Store Guideline 5.1.1.

**How to use it.**

1. Go to Profile and tap "Delete Account."
2. A confirmation dialog warns this is permanent and cannot be undone.
3. Tap "Delete." If Firebase requires a recent sign-in, a re-auth dialog appears: password entry for email accounts, or a provider sign-in prompt for Google/Apple accounts. After re-auth, deletion retries exactly once.
4. On success, a confirmation toast appears and the user is signed out.

**Behind the scenes.**

- The client calls `FirebaseAuth.currentUser.delete()`. This fires the `onUserDeleted` auth trigger, which runs `deleteUserData()` in `functions/src/user_cleanup.ts`.
- `deleteUserData` handles the full data inventory:
  - Deletes: `/users/{uid}` doc, `/users/{uid}/suggestionCounts/*`, `/users/{uid}/reportCounts/*`, all suggestions where `userId == uid`, all reports where `reporterUid == uid`, and all vote docs (across all restaurants) where doc ID == uid.
  - Anonymizes: comments are updated to `userId: "deleted"`, `userName: "Deleted user"`, `isInsider: false`. The comment text is preserved to keep reply threads intact.
- Vote doc deletion fires the `onVoteDeleted` Firestore trigger, which calls `applyVoteDeleted` to decrement the restaurant's `voteCount`. This is Firebase infrastructure wiring, not called directly by the cleanup function.
- The uid is captured before the auth record is deleted (since `currentUser` becomes null after deletion). The caller uses the returned uid to clear uid-scoped SharedPreferences keys (`saved_restaurant_ids_{uid}`, `suggestion_remaining_{uid}`, `voted_restaurant_ids`, and notification preferences).
- Re-auth for `requires-recent-login`: email users enter their password, Google/Apple users tap through a provider re-auth prompt. Retry is capped at one attempt.

**Limits and gotchas.**

- Deletion is irreversible. There is no soft-delete or grace period.
- The cleanup function uses `collectionGroup("votes")` to find all vote docs, which reads every vote doc in the database. At scale, this should be optimized to query by restaurant or maintain a per-user vote index.
- If the auth trigger fails (function cold start, transient error), the auth record is gone but Firestore data may be orphaned. There is no retry mechanism for the cleanup function.

**Where it shows up.**

- The "Delete Account" menu item in Profile (visible only when signed in).
- The confirmation and re-auth dialogs.

<!-- TODO: screenshot of the delete account confirmation dialog -->

---

## Observability (Analytics, Crash Reporting, App Check)

**What it does.** Tracks user behavior for product decisions, catches crashes for debugging, and attests that requests come from real app installs. No PII is collected anywhere in the pipeline.

**How to use it.**

1. Analytics and crash data flow automatically once the Firebase console setup and App Store privacy labels are complete.
2. The debug crash button on the Profile screen (visible only in debug builds) triggers a test crash for verifying Crashlytics.

**Behind the scenes.**

- **Analytics:** All events go through `AnalyticsService` (`lib/services/analytics_service.dart`), a thin abstraction over `FirebaseAnalytics`. Event names and parameter keys are constants; no magic strings. A `FirebaseAnalyticsObserver` on the `MaterialApp` navigator logs screen views automatically. The 11 custom events are: `sign_in`, `sign_up`, `vote_cast`, `save_toggle`, `comment_submit`, `comment_report`, `suggestion_submit`, `paywall_view`, `upgrade_tap`, `share_restaurant`, `account_delete`. Two user properties are set on auth state change: `membership_tier` and `sign_in_method`. A test constructor (`AnalyticsService.test()`) accepts a `List<AnalyticsCall>` sink so tests assert on fired events without Firebase. A `piiFieldNames` blocklist is tested against every event to enforce that no email, display name, photo URL, comment text, password, or token appears in any call.
- **Crashlytics:** Initialized in `main()`. `FlutterError.onError` catches framework errors. `PlatformDispatcher.instance.onError` catches async errors. `setUserIdentifier(uid)` is called on auth state change (uid only, cleared on sign-out). Auth error logs route through `FirebaseCrashlytics.instance.log()` with error codes only, no PII. Custom crash keys: `membership_tier`, `current_screen`, `city_id`. The dSYM upload-symbols build phase is in the Xcode project so symbolication runs automatically on archive builds.
- **App Check:** Activated in `main()` before any Firestore or Cloud Functions calls. Uses App Attest on iOS (debug provider in `kDebugMode`) and Play Integrity on Android (debug provider in `kDebugMode`). Currently monitor-only: the SDK attaches tokens to requests and the Firebase console shows verified vs. unverified traffic, but unverified requests still succeed. Enforcement is a separate console toggle to flip closer to launch after reviewing the traffic split.
- No advertising identifier collection. No IDFA. Firebase Analytics without IDFA does not trigger an ATT prompt.

**Limits and gotchas.**

- App Check is not enforced yet. All requests succeed regardless of attestation status. Enforcement requires a deliberate console step.
- Analytics and crash data only flow after the Firebase console setup (link GA4 property, enable Crashlytics, register App Check providers) and the App Store privacy labels are declared.
- The dSYM upload phase requires the `FirebaseCrashlytics/upload-symbols` binary from the Pods directory. If `pod install` has not been run, the phase fails silently.

**Where it shows up.**

- Analytics: Firebase console > Analytics.
- Crashes: Firebase console > Crashlytics.
- App Check: Firebase console > App Check (verified vs. unverified traffic).
- Debug crash button: Profile screen (debug builds only).

<!-- TODO: screenshot of the debug crash button on the profile screen -->

---

## Suggestion Box

**What it does.** Users can submit feedback, restaurant suggestions, corrections, or city requests from the Profile screen. Capped at 1 per day, enforced server-side.

**How to use it.**

1. Go to Profile and scroll to the Suggestion Box at the bottom.
2. Pick a category: New Restaurant, Correction, New City, or General.
3. Type your suggestion and tap Submit. The counter at the top shows how many submissions remain today (1 of 1).

**Behind the scenes.**

- Suggestions are submitted via the `submitSuggestion` Cloud Function (HTTPS callable). The function enforces the daily cap server-side using a transaction: it reads `/users/{uid}/suggestionCounts/{dateKey}` (where dateKey is the UTC date), checks if the count is >= 1, and either writes the suggestion + increments the counter or rejects with `resource-exhausted`.
- The date key uses server UTC time, not client time, making the cap un-spoofable. This is the key difference from the report rate limit, which is client-side only.
- Suggestions are stored in the `/suggestions` collection with `userId`, `type`, `text`, `cityId` (optional), `createdAt`, and `status` (defaults to `"pending"`).
- Firestore security rules block direct client writes to `/suggestions` (`allow create: if false`). Only the Cloud Function (via admin SDK) can write. Authenticated users can read their own suggestions.
- The client-side `SuggestionProvider` tracks `remainingToday` and `isSubmitting` state for UI feedback. It loads the remaining count from the server on sign-in and falls back to a SharedPreferences cache if the server load fails.
- The daily cap constant is `kDailySuggestionCap = 1` (was 3 in an earlier iteration, reduced to 1 to prevent queue flooding before moderation exists).

**Limits and gotchas.**

- 1 suggestion per day per user, resetting at midnight UTC. The counter at the top reflects this.
- The suggestion types are fixed at four: `newRestaurant`, `correction`, `newCity`, `general`. There is no free-text category field.
- Suggestions queue for manual review. There is no automated processing or status updates visible to the user.

**Where it shows up.**

- The Suggestion Box widget at the bottom of the Profile screen.

<!-- TODO: screenshot of the suggestion box with category chips -->

---

## Membership and Paywall

**What it does.** Three membership tiers control what users can see and do: Free, Locals Pass, and City Insider. The paywall gates access to the Top 10 list, saved restaurants, insider tips, and other premium features.

**How to use it.**

1. Open the Upgrade Plan screen from Profile or tap "See plans" on any paywall gate.
2. Toggle between monthly and yearly billing. Each paid tier shows a "Start 7-day free trial" button.
3. Tap "Restore purchases" at the bottom if you purchased on another device.

**Behind the scenes.**

- **Tier definitions:**
  - Free: Top 5 rankings, voting, commenting.
  - Locals Pass ($4.99/month, $39.99/year): Full Top 10, save restaurants, trending tab, ad-free.
  - City Insider ($9.99/month, $79.99/year): Everything in Locals Pass plus insider tips ("what to order" and "pro tip"), insider badge on comments, verified-visit 3x vote weight (when live), early access to new cities.
- **Client-side gating:** `MembershipProvider` holds the current tier and exposes convenience getters: `canViewTop10`, `canSaveRestaurants`, `canViewInsiderTips`, `hasInsiderBadge`, `isAdFree`. Screens read these to show or hide content and render paywall gates.
- **Server-side gating:** Firestore security rules enforce tier-based access using custom claims on the auth token. Free users (no claim or `membershipTier == "free"`) can only read restaurant docs with `rank <= 5`. Locals Pass and City Insider can read all ranks. Insider notes live in a subcollection (`/restaurants/{id}/insiderNotes/{noteId}`) with a rule requiring `membershipTier == "cityInsider"`.
- **Billing is not wired yet.** `RevenueCatService` is a stubbed service layer. `purchaseTier()` and `restorePurchases()` call the stub. The planned mechanism: a RevenueCat webhook fires a Cloud Function (`setMembershipClaim`, currently a TODO in index.ts) that sets a custom claim on the user's auth token. The client reads the claim on token refresh.
- `MembershipProvider` accepts an `initialTier` constructor parameter for testability, defaulting to `MembershipTier.free`.

**Limits and gotchas.**

- Tiers are not purchasable in-app yet. The upgrade screen renders but purchases do not process until RevenueCat is configured and the custom-claim Cloud Function ships.
- Verified-visit 3x vote weighting is not active. The `weight` field on vote docs is enforced at 1 by security rules. When verified-visit detection ships, the rule will be updated to allow `weight > 1` with a verification claim.
- Client-side gating on saves is present but not server-enforced (deferred until RevenueCat lands). The security rules gate reads (rank-based), but save writes to the user doc are not tier-checked.

**Where it shows up.**

- The Upgrade Plan screen (modal bottom sheet from Profile or paywall gates).
- Paywall gates: blurred Top 10 on the city screen, blurred insider notes on the restaurant detail screen.
- The premium badge next to the user's name in Profile and on comments.

<!-- TODO: screenshot of the upgrade screen with tier cards -->

---

*Last updated: Ranking Engine Block, backfill (2026-06-11).*
