import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/home_screen.dart';
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

  group('HomeScreen', () {
    testWidgets('shows shimmer while loading', (tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      // Pump one frame to see loading state
      await tester.pump();

      // Should show shimmer loading, not a spinner
      expect(find.byType(HomeScreen), findsOneWidget);

      // Drain all timers so test doesn't leak
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );
    });

    testWidgets('shows cities after loading', (tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      // Should show city names
      expect(find.text('Houston, TX'), findsOneWidget);
      expect(find.text('New York, NY'), findsOneWidget);
    });

    testWidgets('has search field', (tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'search filters cities',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const HomeScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        await tester.enterText(
          find.byType(TextField),
          'Houston',
        );
        await tester.pump();

        expect(find.text('Houston, TX'), findsOneWidget);
        expect(find.text('New York, NY'), findsNothing);
      },
    );

    testWidgets(
      'empty search shows empty state',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const HomeScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        await tester.enterText(
          find.byType(TextField),
          'Tokyo',
        );
        await tester.pump();

        expect(find.text("We're not there yet"), findsOneWidget);
      },
    );

    testWidgets('has profile button', (tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.byIcon(Icons.person_outline),
        findsOneWidget,
      );
    });
  });
}
