import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/data/seed_data.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/city_repository.dart';
import 'package:vouch/screens/city_detail_screen.dart';
import 'package:vouch/services/auth_service.dart';

import '../helpers/gated_fixtures.dart';

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
          find.text('Mensho'),
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

  // Fix B step 5. The disclosure is a requirement rather than polish:
  // the baseline holds the curated order for somewhere between three
  // weeks and three months, nobody knows which yet, and an
  // undisclosed thumb on the scale for an unknown number of months is
  // not something the app gets to do quietly.
  //
  // These go through the real Firestore load path (useFirebase: true)
  // rather than through SeedData, because the weight arrives on the
  // city document and the seed path never reads one.
  group('CityDetailScreen opening-list disclosure', () {
    Widget buildWithWeight(double weight) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AppState(
                useFirebase: true,
                cityRepo: _WeightedCityRepository(weight),
                restaurantRepo: GatedFixtureRestaurantRepository(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => MembershipProvider()),
            ChangeNotifierProvider(
              create: (_) => SavedProvider(authService: AuthService.mock()),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  SuggestionProvider(authService: AuthService.mock()),
            ),
            ChangeNotifierProvider.value(value: AuthService.mock()),
          ],
          child: const MaterialApp(
            home: CityDetailScreen(cityId: 'houston'),
          ),
        );

    testWidgets('shows the line while the city baseline still applies',
        (tester) async {
      await tester.pumpWidget(buildWithWeight(0.5));
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      expect(
        find.textContaining(
          'Ranked by locals as votes come in.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('drops the line once the city baseline has expired',
        (tester) async {
      // The absence is the signal. The control below matters: the
      // screen has to still be rendering the city, or this would pass
      // for a blank page.
      await tester.pumpWidget(buildWithWeight(0));
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      expect(find.text('Houston, TX'), findsOneWidget);
      expect(
        find.textContaining(
          'Ranked by locals as votes come in.',
          findRichText: true,
        ),
        findsNothing,
      );
    });
  });
}

/// Serves one Houston with a baselineWeight the test chooses.
///
/// A stub rather than a seeded FakeFirebaseFirestore because the
/// weight is the only variable under test, and the parse itself is
/// covered directly in test/models/city_model_test.dart.
class _WeightedCityRepository extends CityRepository {
  _WeightedCityRepository(this.weight)
      : super(firestore: FakeFirebaseFirestore());

  final double weight;

  @override
  Future<List<City>> getCities() async => [
        SeedData.cities
            .firstWhere((c) => c.id == 'houston')
            .copyWith(baselineWeight: weight),
      ];
}
