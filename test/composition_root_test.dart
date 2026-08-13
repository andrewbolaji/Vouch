// Tests the composition root: the actual object graph main.dart builds,
// via the real VouchApp widget, not a parallel test-only provider stack.
//
// Unit tests that construct AppState directly with an injected
// VoteRepository prove the repository's own logic works. They cannot
// prove main.dart actually passes that repository in, because they
// never call the code that does. That gap is exactly how
// VoteRepository shipped unwired: AppState(membershipProvider:
// membershipProvider) in main.dart never passed voteRepo, so
// toggleVote's `if (_useFirebase && _voteRepo != null)` guard was
// always false in production, votes updated local state and
// SharedPreferences and never reached Firestore, and every existing
// test still passed because none of them went through VouchApp's own
// build() method to find out.
//
// This test does: it pumps the real VouchApp class, with only the
// leaf Firestore dependency substituted for a fake, and asserts a
// vote cast through the real widget tree actually lands in Firestore.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/main.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'the real composition root wires a vote through to Firestore',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('cities').doc('houston').set({
        'name': 'Houston',
        'state': 'TX',
        'imageUrl': 'placeholder://city',
        'description': 'Test city',
      });
      await firestore.collection('restaurants').doc('hou-1').set({
        'cityId': 'houston',
        'name': 'Mensho',
        'cuisine': 'Ramen',
        'imageUrl': 'placeholder://restaurant',
        'description': 'Test restaurant',
        'rank': 1,
      });

      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'test-uid',
          emailVerified: true,
          method: AuthMethod.email,
        ),
      );
      final membershipProvider = MembershipProvider(authService: auth);

      // This is the exact widget main.dart's runApp() constructs,
      // built the same way, with the same build() method. Only the
      // Firestore instance underneath is substituted.
      await tester.pumpWidget(
        VouchApp(
          authService: auth,
          analyticsService: AnalyticsService.test([]),
          membershipProvider: membershipProvider,
          firestoreOverride: firestore,
        ),
      );

      final appState = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Let AppState's real _loadFromFirestore() (not a seed-data
      // fallback, not a test-only useFirebase:false shortcut) resolve
      // against the fake Firestore above.
      for (var i = 0; i < 10 && appState.isLoading; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Proves the read side of the composition root too: if
      // CityRepository/RestaurantRepository had not been wired the
      // same way, this would be empty and the rest of the test would
      // be exercising nothing.
      expect(
        appState.restaurantsForCity('houston'),
        isNotEmpty,
        reason: 'the real AppState built by VouchApp never loaded the '
            'seeded restaurant, so the read side of the composition '
            'root is not wired the way this test needs to prove the '
            'write side',
      );

      appState.toggleVote('hou-1', userId: 'test-uid');

      // toggleVote's Firestore write is fire-and-forget
      // (unawaited(_voteRepo.vote(...))); give it a few turns of the
      // event loop to actually land.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final voteDoc = await firestore
          .collection('restaurants')
          .doc('hou-1')
          .collection('votes')
          .doc('test-uid')
          .get();

      expect(
        voteDoc.exists,
        isTrue,
        reason: 'tapping vote through the real composition root did '
            'not reach Firestore. If this fails, VoteRepository is '
            'not wired into AppState in main.dart again.',
      );

      // SplashScreen (VouchApp's real home) schedules its own
      // navigation timer on a fixed delay unrelated to anything this
      // test checks. Pump past it so the tree has nothing pending at
      // teardown, instead of pumpAndSettle, which loops on AppState's
      // own async work.
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
