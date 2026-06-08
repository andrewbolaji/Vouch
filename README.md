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
flutter test                    # ~185 Dart tests
dart analyze lib/               # 0 warnings expected
```

### Rules and Cloud Function tests

Requires OpenJDK 21+ for the Firebase emulator:

```bash
brew install openjdk@21
export PATH="/usr/local/opt/openjdk@21/bin:$PATH"

# Install test dependencies (one-time)
cd test-rules && npm install && cd ..
cd functions && npm install && cd ..

# Run rules tests (55 tests)
firebase emulators:exec --only firestore 'cd test-rules && npx jest'

# Run Cloud Function tests (8 tests)
firebase emulators:exec --only firestore \
  'npx --prefix functions jest --config functions/jest.config.js'
```

## Tech stack

- Flutter 3.10+ (cross-platform)
- Provider for state management (Riverpod migration planned)
- Firebase (Firestore, Auth, Cloud Functions) with security rules
- freezed + json_serializable for Firestore-ready models
- RevenueCat for IAP -- stubbed, awaiting App Store Connect setup
- SharedPreferences for offline caching
