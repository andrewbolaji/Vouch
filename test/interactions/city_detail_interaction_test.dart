import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/city_detail_screen.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/widgets/paywall_gate.dart';

import '../helpers/gated_fixtures.dart';
import '../helpers/test_app.dart';

/// Ranks a free user is entitled to, read back from what the screen
/// actually received rather than hard coded.
///
/// These assertions used to name restaurants. That pinned the tests
/// to one roster: every rank change broke them, and worse, the
/// findsNothing assertions silently stopped meaning anything once the
/// named restaurant left the seed. The rule is what is under test, so
/// the fixture's own ranks are the source of truth.
List<Restaurant> _freeBand(AppState state) => state
    .restaurantsForCity('houston')
    .where((r) => r.rank <= kFreeTierMaxRank)
    .toList();

void main() {
  // The locked rows are asserted through their semantics labels,
  // which is also the contract a screen reader gets: a row that
  // announces nothing but a redaction bar is unusable. The semantics
  // tree is off by default in tests, so bySemanticsLabel silently
  // finds nothing without this handle.
  late SemanticsHandle semantics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    semantics = TestWidgetsFlutterBinding.instance.ensureSemantics();
  });

  tearDown(() => semantics.dispose());

  group('CityDetailScreen interactions', () {
    testWidgets(
      'Top 5 / Top 10 toggle changes visible content',
      (tester) async {
        final appState = buildGatedFixtureAppState(isPaidTier: false);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        final free = _freeBand(appState);
        expect(free, isNotEmpty, reason: 'fixture must serve a free band');
        for (final r in free) {
          expect(find.text(r.name), findsOneWidget);
        }

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallGate), findsOneWidget);
      },
    );

    testWidgets(
      'free user sees ranks 1 to 5 named and 6 to 10 locked',
      (tester) async {
        final appState = buildGatedFixtureAppState(isPaidTier: false);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // The entitled band, by rank, whatever occupies it.
        for (final r in _freeBand(appState)) {
          expect(
            find.text(r.name),
            findsOneWidget,
            reason: 'rank ${r.rank} is free and must render by name',
          );
        }

        // The gated band, by rank. One locked row per gated rank,
        // counted from the constants rather than from loaded data,
        // because a free user's loaded data holds none of them.
        for (var rank = kGatedRankStart; rank <= kGatedRankEnd; rank++) {
          expect(
            find.bySemanticsLabel(
              'Rank $rank, locked. Upgrade to see this restaurant.',
            ),
            findsOneWidget,
            reason: 'rank $rank is gated and must render as a locked row',
          );
        }

        expect(
          find.text('Unlock full rankings with Locals Pass'),
          findsOneWidget,
        );

        // No gated restaurant reaches the tree. These names exist in
        // kGatedRestaurants, so the absence is the gate working, not
        // a string that was deleted from the codebase.
        for (final r in kGatedRestaurants) {
          expect(find.text(r.name), findsNothing);
          expect(find.text(r.cuisine), findsNothing);
        }
      },
    );

    testWidgets(
      'entitled user sees ranks 6 to 10 named and no paywall',
      (tester) async {
        final appState = buildGatedFixtureAppState(isPaidTier: true);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(
              initialTier: MembershipTier.localsPass,
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallGate), findsNothing);

        // The old version of this test only asserted the paywall was
        // absent, which passed just as well when the section rendered
        // nothing at all. Assert the content is present.
        final gated = appState
            .restaurantsForCity('houston')
            .where((r) => r.rank > kFreeTierMaxRank)
            .toList();
        expect(gated, isNotEmpty, reason: 'fixture must serve a gated band');
        for (final r in gated) {
          expect(find.text(r.name), findsOneWidget);
        }

        // And no locked row survives for someone entitled to see them.
        for (var rank = kGatedRankStart; rank <= kGatedRankEnd; rank++) {
          expect(
            find.bySemanticsLabel(
              'Rank $rank, locked. Upgrade to see this restaurant.',
            ),
            findsNothing,
          );
        }
      },
    );

    testWidgets(
      'paywall renders even though the free user holds no gated rows',
      (tester) async {
        final appState = buildGatedFixtureAppState(isPaidTier: false);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // The precondition that broke this screen. The section used
        // to be gated on this list being non-empty, so the paywall
        // was hidden from every user it exists to convert.
        expect(
          appState
              .restaurantsForCity('houston')
              .where((r) => r.rank > kFreeTierMaxRank),
          isEmpty,
        );

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        expect(find.text('See plans'), findsOneWidget);
        expect(
          find.text('Unlock full rankings with Locals Pass'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'entitled user on the offline fallback is told ranks are missing',
      (tester) async {
        final appState = buildOfflineFallbackAppState(isPaidTier: true);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(
              initialTier: MembershipTier.localsPass,
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(appState.isOffline, isTrue);
        expect(
          appState
              .restaurantsForCity('houston')
              .where((r) => r.rank > kFreeTierMaxRank),
          isEmpty,
          reason: 'the bundled fallback carries free-tier ranks only',
        );

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // Silence here would tell a paying user this city has five
        // restaurants, which is a claim about the city rather than
        // about the failed fetch.
        expect(
          find.textContaining(
            "Couldn't load ranks $kGatedRankStart to $kGatedRankEnd",
          ),
          findsOneWidget,
        );

        // Not a paywall. They already paid for this.
        expect(find.byType(PaywallGate), findsNothing);
        for (var rank = kGatedRankStart; rank <= kGatedRankEnd; rank++) {
          expect(
            find.bySemanticsLabel(
              'Rank $rank, locked. Upgrade to see this restaurant.',
            ),
            findsNothing,
          );
        }
      },
    );

    testWidgets(
      'tapping restaurant navigates to detail screen',
      (tester) async {
        final appState = buildGatedFixtureAppState(isPaidTier: false);
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            appStateOverride: appState,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text(_freeBand(appState).first.name));
        await tester.pumpAndSettle(seedLoadDuration);

        expect(find.byType(RestaurantDetailScreen), findsOneWidget);
      },
    );
  });
}
