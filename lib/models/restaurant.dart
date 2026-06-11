import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant.freezed.dart';
part 'restaurant.g.dart';

/// Sentinel rank for unranked candidate restaurants. The Top 10 is assigned
/// by a rank-computation process (Cloud Function, next Block). Until then,
/// restaurants with this rank sort after all ranked items (1-10) in the
/// Firestore orderBy('rank') query and display by displayOrder instead.
const int kUnrankedRank = 9999;

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
