// Gated restaurant data, for tests only.
//
// This lives under test/ and nowhere else on purpose. Flutter compiles
// lib/ and the assets declared in pubspec.yaml into the app; test/ is
// part of neither, so nothing here reaches a release binary. That is
// the point: ranks above kFreeTierMaxRank and insider notes are paid
// content, and shipping them inside the binary handed them to anyone
// willing to unzip the app.
//
// They cannot simply be deleted, though. docs/DECISIONS.md
// (2026-06-09) records the rule the hard way: a findsNothing
// assertion against a string that exists nowhere passes for the wrong
// reason, and two paywall tests had already been caught asserting
// against garbage-collected names. So the canaries move here rather
// than disappearing.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:vouch/data/seed_data.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/repositories/city_repository.dart';
import 'package:vouch/repositories/restaurant_repository.dart';

/// Restaurants in the gated band, the tier a free user must not see.
///
/// Names match what production carries for Houston, so a findsNothing
/// against them tests the gate rather than testing that a string was
/// deleted.
const List<Restaurant> kGatedRestaurants = [
  Restaurant(
    id: 'hou-14',
    cityId: 'houston',
    name: 'Top Sushi',
    cuisine: 'Sushi',
    imageUrl: 'placeholder://restaurant',
    description: 'Gated fixture.',
    rank: 7,
  ),
  Restaurant(
    id: 'hou-15',
    cityId: 'houston',
    name: 'The Better Box',
    cuisine: 'Sandwiches',
    imageUrl: 'placeholder://restaurant',
    description: 'Gated fixture.',
    rank: 8,
  ),
  Restaurant(
    id: 'hou-16',
    cityId: 'houston',
    name: 'Joey Uptown',
    cuisine: 'New American',
    imageUrl: 'placeholder://restaurant',
    description: 'Gated fixture.',
    rank: 9,
  ),
];

/// A free-visible restaurant carrying insider notes.
///
/// Insider notes are cityInsider-only regardless of rank, so the
/// canary for that gate has to be a note, not a rank.
const Restaurant kInsiderNotesRestaurant = Restaurant(
  id: 'hou-1',
  cityId: 'houston',
  name: 'Mensho',
  cuisine: 'Ramen',
  imageUrl: 'placeholder://restaurant',
  description: 'Free-visible fixture carrying gated insider notes.',
  rank: 1,
  insiderTip: 'No reservations and lines form. Go off-peak, around 4 PM.',
  whatToOrder: 'The Wagyu Texas BBQ Tantanmen (smoked A5 beef).',
);

/// Serves seed cities without touching Firestore.
class GatedFixtureCityRepository extends CityRepository {
  GatedFixtureCityRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<City>> getCities() async => List.from(SeedData.cities);
}

/// Serves the free band plus the gated fixtures, honouring
/// canViewTop10 exactly as the real repository does.
///
/// That filter is the behaviour under test: a free user must receive
/// nothing above kFreeTierMaxRank, which is precisely why the screen
/// cannot derive its locked-row count from loaded data.
class GatedFixtureRestaurantRepository extends RestaurantRepository {
  GatedFixtureRestaurantRepository({this.withInsiderNotes = false})
      : super(firestore: FakeFirebaseFirestore());

  final bool withInsiderNotes;

  @override
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async {
    final free = SeedData.restaurants
        .where((r) => r.cityId == cityId && r.rank <= kFreeTierMaxRank)
        .map(
          (r) => withInsiderNotes && r.id == kInsiderNotesRestaurant.id
              ? kInsiderNotesRestaurant
              : r,
        )
        .toList();
    if (!canViewTop10) return free;
    return [...free, ...kGatedRestaurants.where((r) => r.cityId == cityId)];
  }
}

/// A repository that cannot be reached, to drive the fallback path.
///
/// Throws from getForCity rather than from getCities, because that is
/// where a real read fails once auth and the city list have already
/// succeeded, and it is the case that leaves AppState holding
/// SeedData with isOffline set.
class UnreachableRestaurantRepository extends RestaurantRepository {
  UnreachableRestaurantRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async {
    throw Exception('fixture: restaurant read failed');
  }
}

/// AppState that fell back to the bundled seed, as it does when
/// Firestore is unreachable. isOffline is true and only ranks 1 to
/// kFreeTierMaxRank are present, whatever the user paid for.
AppState buildOfflineFallbackAppState({required bool isPaidTier}) {
  return AppState(
    useFirebase: true,
    isPaidTier: isPaidTier,
    cityRepo: GatedFixtureCityRepository(),
    restaurantRepo: UnreachableRestaurantRepository(),
  );
}

/// AppState on the real Firestore load path, fed by the fixture
/// repositories.
///
/// useFirebase is true on purpose. It selects
/// AppState._loadFromFirestore, which is the code path that reads
/// isPaidTier and passes it to getForCity as canViewTop10. The
/// useFirebase:false path skips that entirely and hands back
/// SeedData, so a test built on it could never exercise the tier
/// filter it claims to be testing.
AppState buildGatedFixtureAppState({
  required bool isPaidTier,
  bool withInsiderNotes = false,
}) {
  return AppState(
    useFirebase: true,
    isPaidTier: isPaidTier,
    cityRepo: GatedFixtureCityRepository(),
    restaurantRepo: GatedFixtureRestaurantRepository(
      withInsiderNotes: withInsiderNotes,
    ),
  );
}
