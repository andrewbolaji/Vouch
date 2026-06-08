import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/user_profile.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';
import 'package:vouch/services/auth_service.dart';

import '../helpers/test_app.dart';

const _testUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this._data);
  final Map<String, List<String>> _data;

  @override
  Future<List<String>> getSavedIds(String uid) async =>
      List.from(_data[uid] ?? []);
  @override
  Future<void> updateSaved(
    String uid,
    String id, {
    required bool add,
  }) async {}
  @override
  Future<UserProfile?> getUser(String uid) => throw UnimplementedError();
  @override
  Future<void> createUser(UserProfile p) => throw UnimplementedError();
  @override
  Future<void> updateLastActive(String uid) => throw UnimplementedError();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedRestaurantsScreen interactions', () {
    testWidgets(
      'empty state shown when nothing is saved',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.text('No saved restaurants yet'),
          findsOneWidget,
        );
        expect(
          find.byIcon(Icons.bookmark_border),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping saved restaurant navigates to detail',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        final repo = _FakeUserRepo({
          'test-uid': ['hou-1'],
        });
        final saved = SavedProvider(
          authService: auth,
          userRepository: repo,
        );

        await tester.pumpWidget(
          buildTestApp(
            const SavedRestaurantsScreen(),
            authOverride: auth,
            savedOverride: saved,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );

        await tester.tap(find.text('Turkey Leg Hut'));
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(RestaurantDetailScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'multiple saved restaurants grouped by city',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        final repo = _FakeUserRepo({
          'test-uid': ['hou-1', 'nyc-1'],
        });
        final saved = SavedProvider(
          authService: auth,
          userRepository: repo,
        );

        await tester.pumpWidget(
          buildTestApp(
            const SavedRestaurantsScreen(),
            authOverride: auth,
            savedOverride: saved,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );
        expect(
          find.text('Peter Luger'),
          findsOneWidget,
        );

        expect(
          find.text('Houston, TX'),
          findsOneWidget,
        );
        expect(
          find.text('New York, NY'),
          findsOneWidget,
        );
      },
    );
  });
}
