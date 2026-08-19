# Interface memory

This is the current product-interface contract and material design-decision history. Read the relevant section before UI work so new screens extend the product Andrew chose instead of drifting toward an agent's preferred style.

## Current interface contract

- **Primary users and context:** Food-culture-literate adults, starting in Houston, who want a fast local shortlist for deciding where to eat. They are expected to open Vouch a few times per week, make a decision and leave.
- **Experience principles:** Opinionated, local, concise and trustworthy. Vouch is a ranked shortlist, not a directory, review average or paid-placement feed. Product choices come from Andrew; agents should surface tradeoffs without replacing his intent with their own taste.
- **Design-system source:** `docs/DESIGN_DIRECTION.md`, `lib/theme/app_theme.dart`, `lib/theme/theme_variants.dart` and shared widgets under `lib/widgets/`.
- **Supported viewports/platforms:** Flutter iOS is the launch target. Android project support exists, but iOS device and TestFlight behavior are the release authority.
- **Accessibility target:** WCAG AA contrast where applicable, at least 44px touch targets, semantic labels, system text scaling and reduced-motion respect. Food photography remains full color.
- **Content voice:** Confident, direct and neighborhood-minded. Errors state what failed and the next useful action. Do not use vague apologies, corporate language, gamification or claims that a submission is acted on when no owned reader exists.
- **Evidence surfaces:** Focused widget and interaction tests, accessibility semantics tests, Linux-authoritative golden tests, and screenshots from the running app for material UI changes.

## State and interaction patterns

| Pattern or component | Required states/behavior | Accessibility and responsive rules | Source/evidence |
|---|---|---|---|
| City discovery | Loading, populated, no search matches, offline fallback and load error must be distinguishable | Search is labeled; cards expose city identity; layouts must tolerate text scaling | `lib/screens/home_screen.dart`, `test/screens/home_screen_test.dart` |
| Ranked city list | Top 5 is public. Top 10 shows real rows only to an entitled user; a free user sees rank placeholders and a paywall without gated fields entering the widget tree | Toggle and locked state need semantics; scrolling and motion stay usable with reduced motion | `lib/screens/city_detail_screen.dart`, `test/screens/city_detail_screen_test.dart` |
| Restaurant detail | Loading or absent data, loaded content, vote write in flight and failure, saved state, comments loading/empty/error/paginated, insider notes locked/empty/error/content | Vote and save actions need explicit labels and at least 44px targets; images need meaningful fallbacks | `lib/screens/restaurant_detail_screen.dart`, `test/screens/restaurant_detail_screen_test.dart`, interaction tests |
| Your Vouches | Signed-out entry routes to sign-in. Signed-in states are loading, empty, grouped active vouches and unavailable detail. The full known count remains visible when one item cannot load | Keep it distinct from Saved Restaurants. Order by city and current rank. A below-Top-5 vouch may render here without entering the free city list | `lib/screens/your_vouches_screen.dart`, `lib/providers/app_state.dart`, focused screen and rules tests |
| Saved restaurants | Empty invitation or grouped-by-city list. Saving is a distinct paid intent, not a synonym for voting | Empty state remains readable at large text; each card exposes restaurant identity and rank | `lib/screens/saved_restaurants_screen.dart`, saved-screen tests |
| Add a Place and suggestions | Signed-out Add a Place routes to sign-in. Signed-in states are available today, daily maximum reached, in flight, stored success and actionable failure. The focused restaurant flow and general suggestion selector share one provider | Explain that one per day is a maximum, not a task. Until the V1 contender pool ships, do not imply that review, candidate publication or photo upload is already operational | `lib/screens/add_place_screen.dart`, `lib/widgets/suggestion_box.dart`, focused screen and interaction tests |
| Reviewed contenders, V1 target | Pending review, duplicate, approved contender, declined, loading, empty, populated, equal-vouch write in flight, rank-entry and rank-exit states | Keep contenders visually and semantically outside ranks 1 through 10. Approval means eligible and visible, never ranked by staff. Every vouch keeps equal weight | `docs/OPEN_LIST_MEASUREMENT.md`, `docs/DECISIONS.md`, implementation evidence pending |
| Profile and account lifecycle | Signed-out sign-in entry, membership, saved list, settings, sign-out and deletion with reauthentication and failure recovery | Destructive actions require explicit confirmation; focus and screen-reader order follow visual order | `lib/screens/profile_screen.dart`, account-deletion tests |

## Decision log

### 2026-08-18T22:43:56Z Keep a reviewed contender pool in V1

- **Status:** active, implementation pending
- **Surface and user problem:** Add a Place can store a missing restaurant, but the pending record has no reader and the ranking engine cannot help a restaurant users cannot discover. That makes “living Top 10” incomplete and leaves city expansion dependent on Andrew manually seeding every place.
- **Decision:** V1 includes operator review, duplicate-safe restaurant identity, approve or decline, a visible contender pool outside the ranked ten, equal-weight vouching and eligibility for the existing daily ranking. Nomination alone never publishes or ranks a restaurant.
- **Why:** This completes the smallest honest growth loop while preserving the distinction between eligibility and rank. It is core to the product promise rather than a social-feed expansion.
- **Alternatives considered:** Defer the full loop to v1.1; publish every nomination immediately; let staff place an approved restaurant directly into the Top 10; keep suggestions as a private founder inbox only.
- **Required states:** Submission stored, operator pending, duplicate, approved, declined, user-visible outcome, contender loading, empty and populated, vote success and failure, and automatic entry to or exit from the ranked ten after recomputation.
- **Accessibility/responsive impact:** Contender identity, eligibility and rank state must be written in text and not communicated only through card position, color or a badge. The surface cannot label contenders as ranks 11 and below because only ten positions are ranked.
- **Implementation evidence:** Pending. The existing ranking-engine behavior is measured in `docs/OPEN_LIST_MEASUREMENT.md`; the intake begins in `lib/screens/add_place_screen.dart`.
- **Revisit when:** The first operator review is exercised end to end. Scope photo uploads and automatic city activation separately rather than attaching them to this loop.
- **Related:** `docs/WISHLIST.md`, `docs/VOUCH_LAUNCH_COMMAND_CENTER.html`, `docs/DECISIONS.md`

### 2026-08-18T01:06:00Z Make community contribution part of the product story

- **Status:** active
- **Surface and user problem:** A generic Profile suggestion box hides the mechanism Vouch needs to discover restaurants and expand beyond cities Andrew can curate. Original local photographs could solve the same scaling problem for restaurant content, but unverified third-party screenshots and contributor-owned originals require different treatment.
- **Decision:** Position restaurant nominations, contributor-owned original photos and city activation as one community-expansion system. Add a focused Add a Place route from Profile and city lists while retaining the general feedback form. State that review and candidate status are coming next. Position photo uploads as planned until private upload, review, attribution and takedown exist. Contributions may create eligibility and receive credit, but never rank.
- **Why:** This makes local participation productive without turning Vouch into a directory or allowing uploads to influence the ranking. It also preserves honesty while the existing pending-suggestion write lacks an operator reader.
- **Alternatives considered:** Keep expansion buried in Suggestion Box; let submissions publish immediately; claim photo ownership can be verified from metadata; reject all user photos; reward photo uploads with vote weight.
- **Required states:** Signed out, one suggestion available, daily maximum reached, in flight, saved, failure, future review status, duplicate, approved candidate and declined. Photo work additionally needs selecting, processing, pending review, approved, declined, reported and removed.
- **Accessibility/responsive impact:** Add a Place uses explicit text and a full-width action rather than icon-only discovery. Ownership and planned-state distinctions are written, not conveyed only by color or badges.
- **Implementation evidence:** `lib/screens/add_place_screen.dart`, city and Profile entry points, `lib/widgets/suggestion_box.dart`, `site/index.html`, `docs/INSTAGRAM_CONTRIBUTOR_POSITIONING.md` and focused tests.
- **Revisit when:** The operator inbox is ready, at which point remove the temporary review-coming copy and expose user-visible statuses. Revisit the daily cap after structured deduplication and moderation metrics exist.
- **Related:** `docs/OPEN_LIST_MEASUREMENT.md`, `docs/WISHLIST.md`, `docs/EXECUTION.md`

### 2026-08-18T00:17:00Z Make Your Vouches a free personal record

- **Status:** active
- **Surface and user problem:** A vote currently changes a button and a city total, but gives the voter no returnable record of the places they supported. Saved Restaurants cannot fill that job because saving means future intent while a vouch means support already given.
- **Decision:** Add Your Vouches to Profile for every signed-in user at no charge. Show all active vouches grouped by city and ordered by current rank, with no silent Top 5 or Top 10 cap and no manual personal ranking. A user's own place remains readable here if it later falls below the free city rows, but that document is kept out of the free city list. If a detail cannot load, preserve it in the count and explain the unavailable item.
- **Why:** The list gains value every time someone vouches and gives them a practical identity and recall surface. Keeping it free maximizes the retention loop. Preserving below-gate vouches avoids the trust break where support appears to disappear merely because a rank changed.
- **Alternatives considered:** Merge votes into paid Saved Restaurants; show only the currently loaded Top 5; cap the user's history at ten; let users reorder a personal ranking; expose every rank-gated restaurant in normal city discovery.
- **Required states:** Signed-out route to sign-in, loading, empty, grouped populated list, below-gate own-vouch detail, unavailable detail and unvote removal.
- **Accessibility/responsive impact:** The profile entry has a distinct label and count. Cards retain their semantic restaurant names and ranks. Missing detail is explained in text and not by icon alone.
- **Implementation evidence:** `lib/screens/your_vouches_screen.dart`, `lib/providers/app_state.dart`, transactional vote-index reconciliation in `functions/src/vote_aggregation.ts`, own-vouch read rules, and focused Flutter, Functions and rules tests.
- **Revisit when:** Usage shows people expect historical removed vouches, private sharing or a manually ordered personal Top 5. Those are separate products, not automatic extensions of this current-vouch record.
- **Related:** `docs/WISHLIST.md`, `docs/USER_GUIDE.md`, `docs/EXECUTION.md`

### 2026-08-18T00:17:00Z Promote Local Guide to the production marketing base

- **Status:** active
- **Surface and user problem:** The approved Local Guide candidate needs to become the real public front door without losing the functioning waitlist or support and privacy routes.
- **Decision:** Use the warm Local Guide design as `site/index.html`, remove the prototype switcher, use production-root assets and fonts, restore the real email and city waitlist request, and retain Instagram, Privacy and Support paths.
- **Why:** Andrew approved the final direction. This preserves the app's paper, ink and flame identity while making restaurant photography, the moving board and Your Vouches utility clearer than the prior dark site.
- **Alternatives considered:** Keep the approved page private; deploy the previous dark local redesign; retain the demo form; preserve the concept switcher on production.
- **Required states:** Desktop and mobile layouts, keyboard-valid form inputs, sending, duplicate, success, validation, rate-limit and network-error copy, plus live support and privacy links.
- **Accessibility/responsive impact:** The page has labeled inputs, live form status, reduced-motion behavior and no horizontal overflow at 390px.
- **Implementation evidence:** `site/index.html`, production assets, local default-viewport and 390 by 844 renders, DOM review, local-reference validation and live waitlist endpoint wiring.
- **Revisit when:** Post-launch conversion or usability evidence shows a specific section blocks signup or obscures the product.
- **Related:** `prototypes/vouch-landing/final-direction/`, `docs/EXECUTION.md`

### 2026-08-17T23:29:30Z Use Local Guide as the final marketing candidate

- **Status:** superseded by the approved production base
- **Surface and user problem:** The marketing site needs to feel like the Block Party app and like a restaurant product, without the party-flyer excess Andrew rejected. It also needs to explain the living ranking and the personal-vouch retention idea clearly.
- **Decision:** Use the Local Guide hybrid as the production candidate. Lead with full-color restaurant photography and a calm editorial serif; keep the app's exact paper, raised paper, ink, flame and gold tokens; use Archivo for controls and Anton only for rank numerals; place one ink-dark ranking band between warm-paper sections; and show Your Vouches plus a weekly movement recap as explicitly labeled product previews.
- **Why:** This preserves the neighborhood confidence and tactile rules Andrew liked in Block Party while borrowing City Scorecard's spacious hierarchy, useful board and personal-list structure. The restraint makes food and product utility lead instead of party energy.
- **Alternatives considered:** Keep Block Party's ticker, yellow circle and oversized “No filler” poster; use City Scorecard's blue as a permanent brand color; return to the dark After Hours publication direction; mechanically combine every liked element.
- **Required states:** The public five-row ranking preview, an honest path to the full list, integrity rules, a distinct personal-vouch preview, a weekly recap preview and an inert concept form that states no email is sent.
- **Accessibility/responsive impact:** High-contrast ink and paper remain primary; flame is not used for small body copy; mobile collapses every grid to one column; the page has no horizontal overflow at 390px; reduced motion is respected.
- **Implementation evidence:** `prototypes/vouch-landing/final-direction/`, default desktop and 390 by 844 browser renders, page-width checks, asset checks and browser-console review.
- **Revisit when:** Andrew approves porting the candidate into `site/index.html`, reconnecting the waitlist endpoint and choosing whether the Your Vouches feature itself is ready to enter app implementation.
- **Related:** `docs/DESIGN_DIRECTION.md`, `docs/WISHLIST.md`, `prototypes/vouch-landing/README.md`

### 2026-08-17T22:58:11Z Keep the marketing concepts exploratory until Andrew chooses

- **Status:** superseded by the Local Guide candidate
- **Surface and user problem:** The marketing site needs a clearer and more distinctive front door, while the local checkout already contains an uncommitted dark redesign and production still serves an earlier version.
- **Decision:** Preserve the existing redesign and compare three isolated directions: After Hours, Block Party and City Scorecard. No concept is the active site until Andrew chooses what to keep or combine.
- **Why:** The alternatives test meaningfully different brand jobs instead of letting an implementation preference silently become the product direction. After Hours tests appetite and editorial authority, Block Party tests continuity with the approved app identity, and City Scorecard tests product clarity plus the Your Vouches retention idea.
- **Alternatives considered:** Directly replace `site/index.html`; make three cosmetic variants of the same dark layout; deploy the unreviewed local redesign to production.
- **Required states:** Each concept includes a clear opening promise, ranked-list proof, anti-paid-placement explanation, early-access action and inert prototype-form confirmation.
- **Accessibility/responsive impact:** All concepts retain high contrast, labeled form controls, visible focus, reduced-motion handling and responsive layouts. Decorative overflow is clipped and food remains full color.
- **Implementation evidence:** `prototypes/vouch-landing/`, desktop and 390 by 844 browser checks, image-load checks, anchor checks and zero browser console warnings or errors.
- **Revisit when:** Andrew chooses one concept, asks for a hybrid, or identifies specific elements to carry into the production site.
- **Related:** `docs/EXECUTION.md`, `prototypes/vouch-landing/README.md`

### 2026-06-01T00:00:00Z Block Party is the chosen visual direction

- **Status:** active
- **Surface and user problem:** Whole-app identity and the need to feel local, appetizing and distinct from generic restaurant apps.
- **Decision:** Use a warm-paper, screenprinted neighborhood-flyer system with ink borders, disciplined hard shadows, large rank numerals, restrained flame and gold accents, and full-color food photography.
- **Why:** Andrew and Christina approved this direction. It supports the anti-directory, city-owned positioning while preserving food appeal.
- **Alternatives considered:** Generic dark restaurant UI, tinted food photography, soft shadows, neon, mascots and motion-heavy gamification.
- **Required states:** Loading, empty, error, success, disabled, locked and offline states use the same visual and content system.
- **Accessibility/responsive impact:** Body copy stays high-contrast ink on paper; flame and gold are not used for small body text; motion is minimal and reduced-motion safe.
- **Implementation evidence:** `docs/DESIGN_DIRECTION.md`, theme tokens, widget tests and golden tests.
- **Revisit when:** User research or device screenshots show the system harms legibility, appetite appeal or task speed.
- **Related:** `docs/DESIGN_DIRECTION.md`

### 2026-08-17T22:07:50Z Keep saved intent separate from voting history

- **Status:** superseded by the free Your Vouches contract
- **Surface and user problem:** Profile currently lists paid saved restaurants, while a user's votes are visible only as filled buttons on individual restaurant details. Andrew proposed a returnable list of places the user has vouched for as a retention surface.
- **Decision:** Treat Saved Restaurants and a future user-vouched list as different product intents. Do not silently rename or merge the paid saved feature. Decide the new list's scope and exactness with Andrew before implementation.
- **Why:** Saving means “I want to remember or visit this.” Voting means “I publicly vouch for this place.” Collapsing them loses both signals and lets an implementation choice rewrite the product idea.
- **Alternatives considered:** Reuse Saved Restaurants and mark votes inside it; show only whichever voted restaurants happen to be in the currently loaded city data; cap the history silently at five or ten.
- **Required states:** Signed out, loading/reconciling, empty, populated, partial/unavailable item, offline and vote-removal states. A list presented as exact cannot rely only on the trigger-maintained convenience index because delivery ordering can make it wrong.
- **Accessibility/responsive impact:** The profile entry needs a distinct label and count. List order and any limit must be explained in text, not color or position alone.
- **Implementation evidence:** Current absence verified in `lib/screens/profile_screen.dart`; server-assisted vote IDs in `functions/src/vote_aggregation.ts`, `lib/models/user_profile.dart` and `lib/providers/app_state.dart`; no voted-list screen exists.
- **Revisit when:** Andrew chooses between all active vouches, a ranked personal top list, or a recent-vouches view, and decides whether it is free or membership-gated.
- **Related:** `docs/EXECUTION.md`, `docs/LEARNINGS.md`

## Open interface questions

| Question | User consequence | Evidence needed | Owner/decision trigger |
|---|---|---|---|
| Should the weekly movement recap arrive as push, email, or an in-app inbox card? | Determines token lifecycle, privacy, delivery cost and whether users can revisit an old recap | Rank-history schema plus a lightweight notification prototype | Andrew after durable rank history exists |
| What is the minimum operator inbox required before nominations are promoted publicly? | Determines when saved nominations can honestly become candidates and receive status updates | Review-state schema, deduplication behavior and an approval-to-candidate test | Codex proposes the slice; Andrew approves the operating workflow before launch |
