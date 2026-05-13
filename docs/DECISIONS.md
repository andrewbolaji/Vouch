# Vouch -- Decisions Log

Architectural and product decisions with reasoning. Future-you reads this file and understands why the system is the way it is.

---

## Standing rules

| Date | Decision | Reason |
|------|----------|--------|
| 2026-05-07 | Em/en dash prohibition (standing rule) | No em dashes or en dashes anywhere in app, user-facing copy, or DECISIONS.md. AI tell. Use commas, periods, parentheses, or rewrite. Apply across all Blocks. |
| 2026-05-07 | 9th-grade reading level for all user-facing copy (standing rule) | All errors, empty states, confirmations, button labels, helper text readable by a 9th grader. No jargon. Concrete next steps in error messages. |
| 2026-05-07 | Tests as deliverables (standing rule) | A Block does not close with zero tests. Tests ship with the feature, not after. |
| 2026-05-07 | Repository pattern: presentation never imports Firebase directly (standing rule) | Screens and widgets never import FirebaseFirestore, FirebaseAuth, etc. All external service access goes through a service or repository layer. Keeps presentation testable and backend-swappable. |
| 2026-05-07 | Theme.of(context) + IconTheme for const-able color reads (standing rule) | Avoids passing runtime colors as constructor params (which breaks const). Widgets read colors from the inherited theme. Unlocks const widget constructors without sacrificing runtime theme switching. |
| 2026-05-07 | User guide (docs/USER_GUIDE.md) maintained live alongside code (standing rule) | Backfilled for Block 0. Updated every Block. Written for the actual user (9th-grade reading, no jargon, no plumbing words). Markdown working format, PDF/Word exported at v1 launch via pandoc. Taste frame (audience check) applied at every Block recap. Block does not close if shipped UI is missing from the guide. |

---

## Architectural decisions

| Date | Decision | Reason |
|------|----------|--------|
| 2026-04-27 | Flutter + Provider for initial state management | Fast cross-platform iteration. Provider is simple for the current scope (4 providers). Riverpod selected as the migration target once interaction tests provide a safety net. |
| 2026-04-27 | Riverpod selected over Provider continuation | Provider's BuildContext coupling makes testing harder and breaks in non-widget contexts. Riverpod eliminates this. Migration deferred until interaction tests pass (trigger now fired, tests complete). |
| 2026-04-27 | very_good_analysis over flutter_lints | Stricter rule set catches more issues at lint time. Enforces consistent style without manual review burden. Team-ready from day 1. |
| 2026-04-27 | cached_network_image over raw Image.network | Built-in disk + memory caching, placeholder/error widget support, avoids re-downloading on rebuild. Worth the dependency for an image-heavy app. |
| 2026-04-27 | Seed data with `kUseFirebase` flag, not Firebase from day 1 | Build the full UI and test suite before introducing network dependencies. Firebase wiring is a separate Block. Allows full offline development and fast test cycles. |
| 2026-04-27 | SharedPreferences for votes and saved restaurants (local persistence) | Near-zero failure rate on device storage. Acceptable for prototype phase. Migrates to Firestore when `kUseFirebase` flips. |
| 2026-04-27 | Three-tier membership: Free, Locals Pass, City Insider | Free gets Top 5 + vote/comment. Locals Pass ($4.99/mo) adds Top 10, saves, ad-free. City Insider ($9.99/mo) adds insider tips, badge, 2x vote weight. |
| 2026-04-27 | Client-side paywall gating only (for now) | All data is local seed data. No security risk in current state. Server-side gating is non-negotiable when Firebase is live. |
| 2026-04-27 | RevenueCat for IAP, mock mode until configured | Service layer stubbed with TODO comments. Real SDK activation requires App Store Connect products + RevenueCat dashboard setup. |
| 2026-04-27 | Mock auth with SharedPreferences persistence | Firebase Auth not yet configured. Mock stores email and display name only (no password, no token). No sensitive data at risk. |
| 2026-05-01 | Firestore region: us-central1 | Lowest latency to launch markets (Houston, NYC, LA, Chicago). Cannot change after project creation without full data migration to new project. Multi-region (nam5) rejected: adds cost, no benefit until international expansion. |
| 2026-05-01 | savedRestaurantIds as array on user doc, not subcollection | Single-read pattern. Atomic arrayUnion/arrayRemove. Won't hit 1MB even at 1000 saves (~10 bytes per ID). Subcollection would require a query per load. |
| 2026-05-01 | Comments as subcollection of restaurants, not array on doc | Unbounded growth. Requires paginated queries (page size 20, cursor-based with startAfter). Array on doc would hit 1MB limit. |
| 2026-05-01 | Vote doc ID = user UID (subcollection of restaurants) | Enforces one-vote-per-user at storage level. set() overwrites, not duplicates. No security rule needed to prevent duplication. voteCount denormalized on restaurant doc via Cloud Function onWrite trigger. |
| 2026-05-01 | Custom claims on auth token for membership gating | Security rules read claims from request.auth.token without extra Firestore reads. RevenueCat webhook sets the claim via Cloud Function. Claims limited to 1000 bytes but tier is a single string. |
| 2026-05-01 | Cloud Function proxy for insider field stripping | Firestore has no field-level read rules. getRestaurant Cloud Function checks custom claim and strips insiderTip/whatToOrder for non-entitled users. Direct Firestore reads for non-gated data only. |
| 2026-05-01 | Suggestion rate limit: counter doc + transaction, not Cloud Function gate | Faster (no HTTP call latency). Atomic read-check-write in standard Firestore transaction. Server-enforced. Client-side cap is UX only. |
| 2026-05-01 | MembershipProvider.initialTier constructor parameter for testability | Avoids mock purchase delays in tests. Defaults to MembershipTier.free. Zero production behavior change. Used by test helper buildTestApp. |
| 2026-05-01 | Comment ID via millisecondsSinceEpoch (seed data only) | Acceptable for local seed data. Firestore will use auto-generated IDs when wired. |
| 2026-05-07 | Framework files stored in docs/ | AI_BUILD_FRAMEWORK.md, BLOCK_TEMPLATES.md, REVIEW_FRAMEWORK.md, DECISIONS_AND_WISHLIST_DISCIPLINE.md organized under docs/ for separation from source. |
| 2026-05-07 | Concurrent sessions: allow | Standard consumer-app expectation. Firebase handles natively. No work needed. |
| 2026-05-07 | Password reset: defer to Firebase default web handler for v1 | In-app deep link handling requires go_router, which is itself deferred. Pinned in WISHLIST.md v1.1 with trigger: "When go_router ships." |
| 2026-05-07 | Account deletion: v1 scope, non-negotiable | Apple App Store guideline 5.1.1(v) requires it. Block 1 ships auth-level deletion (FirebaseAuth.currentUser.delete()). Cloud Function for Firestore user data cleanup ships in Block 2 or 3 when Firestore data exists. Profile menu entry with confirmation modal. |
| 2026-05-07 | AuthService owns authStateChanges() stream | Enforces single subscription per app instance. Preserves repository pattern (callers never import FirebaseAuth). Automatic disposal when MultiProvider tears down. Implementation: late final StreamSubscription in constructor, cancelled in dispose(). |
| 2026-05-07 | Auth methods for v1: email + password, Google, Apple | Email link/passwordless deliberately deferred. Google/Apple already solve the password-averse use case. Email link requires deep-link infrastructure deferred to go_router. Pinned in WISHLIST.md v2 with trigger: "go_router ships AND password-fatigue feedback." |
| 2026-05-09 | Suggestion daily cap: 1/day (was 3/day) | 1 is enough to signal engagement without flooding the queue before moderation exists. 24-hour reset window unchanged. |
| 2026-05-09 | Premium vote weight: 3x | 2x is mathematically too small to feel meaningful or justify $5/mo; 5x feels oligarchic, risks App Store "pay-to-win" framing, and silences free users to the point of breaking the brand promise. 3x is meaningful but coordinated free-user communities can still shift rankings. "Triple" is also the most legible language for users. |
| 2026-05-09 | No ads in v1 | Ad-free is the foundational premium feature; introducing ads to free tier without a meaningful free user base destroys the premium pitch and generates near-zero revenue. Trigger to revisit: 10K+ DAU AND ad-free is no longer the strongest premium differentiator (e.g., after vote weight has been repositioned as the headline premium feature). |
| 2026-05-09 | Vote breakdown display visible to all users including free tier | Transparency is the ethical defense for the premium-vote-weight model. Users see how rankings form and decide for themselves if they trust the math. Paywalling the receipts would defeat the point. |
| 2026-05-09 | Launch city scope expanded to 5 cities (Houston, Atlanta, New Orleans, Chicago, San Francisco) | Curated via TikTok food creator candidates + Reddit + Eater + Michelin pipeline. Andrew sources Top 10 candidates per city; voting forms the final Top 5 visible to free users with bottom 5 dimmed/locked behind premium. Seed data city count unchanged in this Block. NYC deferred: too large and too competitive at launch; revisit after 3 months live with the initial 5. |
| 2026-05-09 | App bundle ID: com.example.majorcitymusteats | Matches the legacy Firebase Project ID kept as project lore. Don't rename without coordinated Firebase reconfigure. All platforms (iOS, Android, macOS, Linux, web) aligned to this ID. |
| 2026-05-09 | Google Places usage policy: intake-only | Vouch uses Google Places API only at suggestion intake (autocomplete + one Place Details call per accepted suggestion). All restaurant data subsequently lives in Vouch's Firestore. Vouch does NOT re-fetch from Google on page loads. Reasoning: re-fetching on every page view would cost ~$2,500/month at 1K DAU; current architecture caps spend at ~$50-100/month at the same scale. Place ID stored as the canonical dedup key. |

---

## Trigger-based deferrals (pinned)

| Date | Decision | Trigger |
|------|----------|---------|
| 2026-04-27 | Folder restructure to feature-first | File count crosses 60 OR a new feature domain is added. Current: 42 .dart files in lib/. |
| 2026-04-27 | freezed + json_serializable models | Firebase data layer is wired (kUseFirebase = true), requiring Firestore serialization. |
| 2026-05-01 | Sealed AppException hierarchy | Block 1 (Firebase Auth wire-up). Auth layer needs it to wrap FirebaseAuthException at the boundary. Trigger fired. |
| 2026-05-01 | Crashlytics + structured logging | flutterfire configure is run and Firebase project is connected. |
| 2026-05-01 | Firestore security rules + server-side content gating | kUseFirebase flipped to true and at least one Firestore collection is in use. Non-negotiable when triggered. |
| 2026-05-01 | Secure auth token storage (flutter_secure_storage) | Firebase Auth is wired and real auth tokens exist. Block 1 trigger. |
| 2026-05-01 | Suggestion daily cap: switch to UTC | Firebase is live and suggestion cap is server-enforced. Client should match server timezone. |
| 2026-05-01 | User-visible persistence error feedback (SnackBar + retry) | Firebase is live and real write failures are possible (network, permissions, quota). |
| 2026-05-01 | Reconcile cost model against Firebase Console actuals | 30 days after first 100 DAU sustained. Compare estimates to billing reality. |
