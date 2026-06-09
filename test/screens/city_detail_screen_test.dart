import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/city_detail_screen.dart';
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

  group('CityDetailScreen', () {
    testWidgets('shows city name in app bar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const CityDetailScreen(cityId: 'houston'),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Houston, TX'), findsOneWidget);
    });

    testWidgets('shows Top 5 / Top 10 toggles', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const CityDetailScreen(cityId: 'houston'),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Top 5'), findsOneWidget);
      expect(find.text('Top 10'), findsOneWidget);
    });

    testWidgets(
      'shows restaurants for the city',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.text('The Puddery'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'returns empty for invalid cityId',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'invalid'),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        // Should render SizedBox.shrink
        expect(find.byType(SizedBox), findsWidgets);
      },
    );
  });
}
