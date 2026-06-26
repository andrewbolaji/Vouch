# Vouch -- Product Spec

---

## Who this is for

Vouch is for the 25-40 year old in Houston (expanding to other US cities) who is tired of scrolling through Yelp reviews and Google Maps stars to find a good restaurant. They trust personal recommendations over algorithmic ones. They discovered Vouch through a partner's social media following or word-of-mouth from early Houston users, not from app store search. They use the app for two decisions: "where should I eat tonight" and "where should I take a visiting friend." They care about authenticity signals (locals voted this in) more than star ratings or review count. They are not a power user. They open the app 2-3 times a week, make a decision, and close it. The UI must respect that: fast to value, no onboarding friction, no content buried behind navigation depth.

---

## Vision

A curated, community-voted Top 10 restaurant list for every major city. Not another review platform. Not another Yelp. A short, opinionated list that answers "where do locals actually eat?" with social proof (vote counts) and insider knowledge (tips from City Insiders). The constraint (only 10 per city) is the feature, not the limitation.

---

## v1 scope

- 4 launch cities: Houston, NYC, LA, Chicago
- Curated Top 10 per city (editorially seeded, community-voted)
- Three membership tiers: Free (Top 5, vote, comment), Locals Pass (Top 10, save, ad-free), City Insider (insider tips, badge, 3x vote weight)
- Firebase Auth (Email, Google, Apple)
- Firestore data layer with security rules
- RevenueCat IAP integration
- Push notifications (new city launches, weekly picks)
- Share/deep-link support
- 100+ automated tests

---

## Deferred scope

See `docs/WISHLIST.md` for the full tiered wishlist with triggers and reasoning.

Key deferrals:
- Riverpod migration (v1.1, trigger fired)
- go_router deep links (v1.1, trigger: share feature)
- freezed models (v1.1, trigger: Firebase wired)
- Operations metrics (v2, trigger: 500 DAU + 3 months data)
- AI query layer (v3+, trigger: v2 metrics + 6 months data)

---

## Running lessons (captured live during build)

### From initial refactor

- **The writeup must not do work the diff didn't.** A confident, well-organized writeup can make work look more thorough than it was. Senior reviewers spot this immediately. Audits should report counts and file references, not assertions. Silence on a deliverable is read as "didn't run."

- **Planning enumerates deliverables; adversarial passes catch edge cases.** When MembershipProvider tests were missed in initial planning and caught only in the adversarial pass, that was a planning failure, not a process success. Adversarial passes are the safety net, not the primary detector.

- **Frame diversity is the technique, not pass count.** One taste-frame pass plus one operational-frame pass catches different bugs than two taste-frame passes. The pre-launch security audit on Vouch's paywall added the third frame. All three frames are now part of the standard process.

- **Trigger-based deferrals beat vague timelines.** "When SavedProvider has tests" is testable. "Next session" isn't. The deferrals that survived from the initial refactor to here are the ones with concrete triggers.

- **Const optimization in Flutter is unlocked by Theme.of + IconTheme, not by making colors compile-time constants.** The original const audit was defeatist; the second look found a real pattern that fixed three sites without breaking runtime theme switching.

- **Premium content gating must withhold from the widget tree, not just visually hide.** The DevTools-bypass finding from the security pass was the highest-impact catch of the refactor. "Visually hidden behind a blur" is not gating; "real data not present in the widget tree until entitlement verified" is.

- **Cost-modeling a schema before launch surfaces the dominant cost driver.** For Vouch, comments pagination dominates Firestore reads, not votes. Intuition would have guessed wrong. The 345-DAU free-tier inflection point is information needed before a billing alert, not after.
