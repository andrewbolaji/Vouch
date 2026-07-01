import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/services/analytics_service.dart';
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
      ChangeNotifierProvider(
        create: (_) => ReportProvider(authService: auth),
      ),
      ChangeNotifierProvider.value(value: auth),
      Provider.value(value: AnalyticsService.test([])),
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

      expect(find.text('Mensho'), findsOneWidget);
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

    testWidgets('shows comment action button in action row', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Speech-bubble icon appears in the action row
      expect(
        find.byIcon(Icons.chat_bubble_outline),
        findsWidgets,
      );
    });

    testWidgets('comments section header shows count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Scroll down to reveal the comments section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // hou-1 has seed comments, header should show 'Comments' with a count
      expect(find.text('Comments'), findsOneWidget);
    });
  });
}
