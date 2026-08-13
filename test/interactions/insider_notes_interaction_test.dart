import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/widgets/insider_notes.dart' as w;
import 'package:vouch/widgets/paywall_gate.dart';

import '../helpers/gated_fixtures.dart';
import '../helpers/test_app.dart';

/// Finding 2: the insider notes section was unreachable for everyone.
///
/// The gate read `restaurant.whatToOrder != null || restaurant.insiderTip
/// != null`. Neither can ever be non-null, because
/// `RestaurantRepository._parseRestaurant` sets both to null on every
/// parse: they are legacy fields, and the real content lives in the
/// `insiderNotes` subcollection. So nobody saw notes and nobody saw the
/// pitch for them, paid or free, for three months.
///
/// These tests all drive the notes through `getInsiderNotes`, the real
/// subcollection read, and leave the restaurant's own fields null the
/// way the production parser leaves them. A fixture that set those
/// fields would test a path production does not have, and would have
/// gone on passing throughout the outage.
const _notes = InsiderNotes(
  restaurantId: 'hou-1',
  insiderTip: 'Go off-peak, around 4 PM.',
  whatToOrder: 'The Wagyu Texas BBQ Tantanmen.',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Insider notes', () {
    testWidgets(
      'entitled user with a notes subdocument sees the notes',
      (tester) async {
        final appState = buildInsiderNotesAppState(notes: _notes);

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(restaurantId: 'hou-1'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(
              initialTier: MembershipTier.cityInsider,
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // The precondition that made this unreachable. The restaurant
        // object itself carries nothing, exactly as in production.
        final restaurant = appState.restaurantById('hou-1');
        expect(restaurant, isNotNull);
        expect(restaurant!.insiderTip, isNull);
        expect(restaurant.whatToOrder, isNull);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();

        expect(find.byType(w.InsiderNotes), findsOneWidget);
        expect(find.textContaining('Tantanmen'), findsWidgets);
        expect(find.byType(PaywallGate), findsNothing);
      },
    );

    testWidgets(
      'entitled user with no notes sees the empty state, not a paywall',
      (tester) async {
        // The state Houston is actually in today: the 33 generated
        // notes were deleted on 2026-08-13 and Andrew has not written
        // real ones yet. Empty is the correct answer, and somebody
        // has to have looked at it.
        final appState = buildInsiderNotesAppState();

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(restaurantId: 'hou-1'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(
              initialTier: MembershipTier.cityInsider,
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No insider notes for this one yet'),
          findsOneWidget,
        );
        // Not a paywall. They already paid.
        expect(find.byType(PaywallGate), findsNothing);
        expect(find.byType(w.InsiderNotes), findsNothing);
      },
    );

    testWidgets(
      'entitled user whose read fails sees an error with a retry',
      (tester) async {
        final appState = buildInsiderNotesAppState(throwOnRead: true);

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(restaurantId: 'hou-1'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(
              initialTier: MembershipTier.cityInsider,
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();

        // A failed read must not read as "nothing written here".
        expect(
          find.textContaining("Couldn't load the insider notes"),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(
          find.textContaining('No insider notes for this one yet'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'free user sees the paywall and never the notes',
      (tester) async {
        // Notes exist, and the free user must still not receive them.
        final appState = buildInsiderNotesAppState(notes: _notes);

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(restaurantId: 'hou-1'),
            appStateOverride: appState,
            membershipOverride: MembershipProvider(),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallGate), findsOneWidget);
        expect(find.text('City Insider exclusive'), findsOneWidget);
        expect(find.textContaining('Tantanmen'), findsNothing);
        expect(find.textContaining('4 PM'), findsNothing);

        // And the read was never attempted, because rules would deny
        // it. The free branch is driven by the entitlement, not by
        // data the client cannot legally have.
        expect(
          appState.insiderNotesFor('hou-1').status,
          InsiderNotesStatus.notLoaded,
        );
      },
    );

    testWidgets(
      'upgrading while on the screen loads the notes',
      (tester) async {
        // initState fires the load exactly once, and only when the
        // user is already entitled. Somebody who upgrades from this
        // screen, which is the flow the paywall's own CTA produces,
        // was never entitled at initState. Without a second trigger
        // they sit on a spinner forever, having just paid.
        final appState = buildInsiderNotesAppState(notes: _notes);
        final membership = MembershipProvider();

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(restaurantId: 'hou-1'),
            appStateOverride: appState,
            membershipOverride: membership,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          appState.insiderNotesFor('hou-1').status,
          InsiderNotesStatus.notLoaded,
        );

        membership.setTierForTest(MembershipTier.cityInsider);
        await tester.pumpAndSettle();

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();

        expect(find.byType(w.InsiderNotes), findsOneWidget);
        expect(find.textContaining('Tantanmen'), findsWidgets);
        expect(find.byType(PaywallGate), findsNothing);
      },
    );
  });
}
