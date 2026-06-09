import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/services/auth_service.dart';

Widget buildTestApp(Widget child) {
  final auth = AuthService.mock();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider(create: (_) => SavedProvider(authService: auth)),
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

  group('RestaurantDetailScreen', () {
    testWidgets('shows not found for bad id', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'invalid',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.text('Restaurant not found'),
        findsOneWidget,
      );
    });

    testWidgets('shows restaurant name', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('The Puddery'), findsOneWidget);
    });

    testWidgets('has comment input', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows vote button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.byIcon(Icons.arrow_upward_rounded),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows share button in app bar',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.byIcon(Icons.share_outlined),
          findsOneWidget,
        );
      },
    );
  });
}
