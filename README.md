# Vouch

Curated Top 10 restaurant rankings, one definitive list per city, voted on by locals. Built as a polished iOS app with a server-enforced membership model and a tested, abuse-resistant voting system.

## What it does

- **One list per city.** Each city has a single curated Top 10, so the list stays definitive instead of endless.  
- **Locals vote.** One vote per user is enforced at the database layer, and a daily time-decay ranking keeps lists current.  
- **Three-tier membership.** A server-side paywall gates premium features. Entitlements are enforced with custom auth claims and a Cloud Function that strips premium fields for non-members, so the client is never trusted with access decisions.  
- **Built to ship.** 380 automated tests, including Firestore security-rules tests and Cloud Function suites.

## Tech stack

- Flutter and Dart  
- Firebase (Firestore, Auth, Cloud Functions)  
- Provider for state management  
- RevenueCat for in-app purchases (planned)  
- Firebase emulator suite for rules and function tests

## Architecture notes

- **Trust boundary.** Premium access is enforced server-side. A Cloud Function strips premium fields from responses for non-members and custom auth claims drive entitlement checks, so a modified client cannot unlock paid content.  
- **Vote integrity.** One vote per user is enforced in the data layer rather than the UI, and rankings are computed with a daily time-decay so older votes weigh less.

## Getting started

### Prerequisites

- Flutter SDK (stable channel)  
- A Firebase project with Auth (email/password) and Firestore enabled  
- Node.js, for Cloud Functions and rules tests  
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

### Setup

git clone https://github.com/andrewbolaji/Vouch.git

cd Vouch

flutter pub get

flutterfire configure \--project=YOUR\_PROJECT\_ID

flutter run

### Running tests

```bash
# Flutter/Dart tests (282 tests)
flutter test

# Cloud Function tests (27 tests)
cd functions && npm test

# Firestore security rules tests (71 tests, requires Firebase emulator)
cd test-rules && npm test
```

## Project docs

See `docs/` for the product spec, user guide, decisions log, and feature wishlist.  
