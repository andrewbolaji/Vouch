import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant.freezed.dart';
part 'restaurant.g.dart';

/// Sentinel rank for unranked candidate restaurants. The Top 10 is assigned
/// by a rank-computation process (Cloud Function, next Block). Until then,
/// restaurants with this rank sort after all ranked items (1-10) in the
/// Firestore orderBy('rank') query and display by displayOrder instead.
const int kUnrankedRank = 9999;

/// Highest rank a free user may read. firestore.rules enforces the
/// same boundary server-side, so this constant describes the gate, it
/// does not create it.
const int kFreeTierMaxRank = 5;

/// The gated band, rendered to a free user as locked rows.
///
/// A product constant, deliberately not derived from the number of
/// restaurants the client happens to hold or from
/// cities.restaurantCount. A free user never receives a document
/// above kFreeTierMaxRank, so any count taken from loaded data is
/// zero for them, and restaurantCount is a known drifting
/// denormalization with no sync mechanism.
const int kGatedRankStart = kFreeTierMaxRank + 1;
const int kGatedRankEnd = 10;

@freezed
abstract class RestaurantLocation with _$RestaurantLocation {
  const factory RestaurantLocation({
    required String name,
    required String address,
    @Default(0) double latitude,
    @Default(0) double longitude,
  }) = _RestaurantLocation;

  factory RestaurantLocation.fromJson(Map<String, dynamic> json) =>
      _$RestaurantLocationFromJson(json);
}

@freezed
abstract class Restaurant with _$Restaurant {
  const factory Restaurant({
    required String id,
    required String cityId,
    required String name,
    required String cuisine,
    required String imageUrl,
    required String description,
    required int rank,
    @Default(0) int voteCount,
    @Default(0) int commentCount,
    @Default(2) double priceLevel,
    @Default([]) List<RestaurantLocation> locations,
    String? insiderTip,
    String? whatToOrder,
    @Default([]) List<String> vibeTags,
    String? placeId,
    @Default(false) bool isMobileVenue,
    @Default([]) List<String> openingHours,
    @Default(0) int displayOrder,
    @Default(0) double rankScore,
  }) = _Restaurant;

  const Restaurant._();

  factory Restaurant.fromJson(Map<String, dynamic> json) =>
      _$RestaurantFromJson(json);

  String get priceLevelDisplay => r'$' * priceLevel.round();

  bool get isUnranked => rank >= kUnrankedRank;
}
