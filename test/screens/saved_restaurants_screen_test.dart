import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/user_profile.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';
import 'package:vouch/services/auth_service.dart';

const _testUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo([this._ids = const []]);
  final List<String> _ids;

  @override
  Future<List<String>> getSavedIds(String uid) async => List.from(_ids);
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
  @override
  Future<void> addBlock(String blockerUid, String blockedUid) async {}
  @override
  Future<void> removeBlock(String blockerUid, String blockedUid) async {}
  @override
  Future<List<String>> getBlockedIds(String uid) async => [];
}

Widget buildTestApp(
  Widget child, {
  AuthService? authOverride,
  SavedProvider? savedOverride,
}) {
  final auth = authOverride ?? AuthService.mock();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider(
        create: (_) => savedOverride ?? SavedProvider(authService: auth),
      ),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: auth),
      ),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedRestaurantsScreen', () {
    testWidgets('shows empty state with no saves', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SavedRestaurantsScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.text('No saved restaurants yet'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Save your favorites and they will appear here',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Saved title', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SavedRestaurantsScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets(
      'shows saved restaurants when populated',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        final saved = SavedProvider(
          authService: auth,
          userRepository: _FakeUserRepo(['hou-1']),
        );

        await tester.pumpWidget(
          buildTestApp(
            const SavedRestaurantsScreen(),
            authOverride: auth,
            savedOverride: saved,
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.text('Mensho'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows empty bookmark icon',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.byIcon(Icons.bookmark_border),
          findsOneWidget,
        );
      },
    );
  });
}
