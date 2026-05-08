# Vouch

Curated Top 10 restaurant rankings per city, voted on by locals.

## Project docs

- `docs/VOUCH_SPEC.md` -- product spec, user description, v1 scope, running lessons
- `docs/USER_GUIDE.md` -- user-facing guide (9th-grade reading level, no jargon)
- `docs/DECISIONS.md` -- architectural and product decisions with reasoning
- `docs/WISHLIST.md` -- tiered feature wishlist (v1.1, v2, v3+, Business, Skipped)
- `FIRESTORE_SCHEMA.md` -- Firestore schema design doc
- `HANDOFF.md` -- session handoff notes

## Build framework

- `docs/AI_BUILD_FRAMEWORK.md` -- how to build with AI as implementer
- `docs/BLOCK_TEMPLATES.md` -- block kickoff and recap prompt templates
- `docs/REVIEW_FRAMEWORK.md` -- three-frame adversarial review process
- `docs/DECISIONS_AND_WISHLIST_DISCIPLINE.md` -- how to maintain DECISIONS.md and WISHLIST.md

## Getting started

```bash
flutter pub get
flutter run
flutter test        # 100 tests, ~15s
flutter analyze     # 0 issues expected
```

## Tech stack

- Flutter 3.10+ (cross-platform)
- Provider for state management (Riverpod migration planned)
- Firebase (Firestore, Auth, Messaging) -- currently in mock/seed data mode
- RevenueCat for IAP -- stubbed, awaiting App Store Connect setup
- SharedPreferences for local persistence
