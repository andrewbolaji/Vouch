# Vouch

## What this is

Vouch is a Flutter iOS app that keeps one curated Top 10 restaurant list per city, ranked by local votes with daily time decay. Membership tiers are enforced server side by Cloud Functions and custom auth claims, so a modified client cannot unlock paid content.

## First 10 minutes

Every command below was run here, except the last block (needs a Firebase login and a device).

```bash
flutter pub get
flutter test --exclude-tags=golden   # 312 tests, ~40s, no emulator needed
```

The other suites need the Firestore emulator, hence Java on PATH:

```bash
export PATH="$(brew --prefix openjdk)/bin:$PATH"

firebase emulators:exec --only firestore,auth --project vouch-test \
  'cd functions && npx jest --forceExit'        # 63 tests

(cd test-rules && npm run test:emulator)       # 79 tests
```

Lint and build:

```bash
flutter analyze                            # see baseline in gotchas
(cd functions && npm run lint && npm run build)
```

Launching the app needs the generated Firebase config, which is not in git:

```bash
dart pub global activate flutterfire_cli    # not installed by default
flutterfire configure --project=majorcitymusteats
flutter run
```

## Architecture map

- `lib/`: `models/` (freezed, generated), `repositories/` (all Firestore I/O), `providers/`, `screens/`, `widgets/`, `services/` (auth, RevenueCat, analytics).
- `functions/src/`: `index.ts` triggers delegate to pure modules (`rank_engine.ts`, `membership_webhook.ts`), testable without a database.
- `firestore.rules` is the real trust boundary, covered by `test-rules/src/`. Entitlement claims and premium stripping live in functions, never the client.
- `test/` mirrors `lib/` by layer, plus `goldens/` (pixel baselines) and `interactions/` (multi-step widget flows).
- `scripts/` admin and seed scripts. `docs/` spec, decisions, handbook.

## Gotchas

- `cd functions && npm test` **hangs forever** instead of failing: bare jest blocks connecting to an emulator at `127.0.0.1:8080`. Always use `firebase emulators:exec`.
- Homebrew's `openjdk` is keg-only, so Java is off PATH. Without the `export PATH` line above, emulator commands die with "Unable to locate a Java Runtime."
- `lib/firebase_options.dart` is gitignored and generated. Until you run `flutterfire configure`, `flutter analyze` reports 4 errors and the app will not build. `flutter test` still passes, no test imports it.
- `flutter analyze` baseline is **0 issues**. Any new issue is a regression. (Before `flutterfire configure` has been run, it reports 4 errors instead, from the missing `firebase_options.dart`.)
- Goldens are CI-authoritative: baselines are generated on ubuntu-latest by `.github/workflows/update-goldens.yml`, not on a developer machine. Run `flutter test --exclude-tags=golden` locally. macOS renders fonts differently than Linux, so running the golden tests on a Mac produces pixel diffs against the Linux baselines. That diff is expected and is not a regression, it just means the golden run is not meaningful outside CI. `golden_harness.dart` mocks `path_provider` and swaps sqflite for FFI, without which `CachedNetworkImage` widgets crash headless.
- `functions/package.json` pins `engines.node: 22`, local Node v20. Only `firebase deploy` cares.
- Swift Package Manager and the UIScene lifecycle migration are declined on purpose (`pubspec.yaml`'s `flutter: config:` block). Both are Flutter tool defaults now, and the first `flutter build ios` after a working Xcode install will migrate the Xcode project to both if nothing stops it, dirtying tracked files and switching build systems the week we ship. CocoaPods works, every plugin supports it, and the UIScene migration is real but not due yet. Don't re-enable either without a deliberate commit and device testing.

## Definition of done

1. Plan agreed before non-trivial code.
2. Tests pass, and new behavior has a test beyond the happy path.
3. Lint and typecheck clean against the baseline.
4. Diff self-reviewed before offering it.
5. UI changes verified by screenshot.
6. Committed **and pushed**. Uncommitted work does not exist.

## House style

Applies to every file and commit message, subject and body.

- No em dashes, ever. Use commas, periods, or parentheses.
- Sentence case headings.
- Match the surrounding file's comment density and naming. Comments say why, not what.
