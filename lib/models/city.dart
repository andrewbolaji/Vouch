import 'package:freezed_annotation/freezed_annotation.dart';

part 'city.freezed.dart';
part 'city.g.dart';

enum CityStatus { live, comingSoon }

@freezed
abstract class City with _$City {
  const factory City({
    required String id,
    required String name,
    required String state,
    required String imageUrl,
    required String description,
    @Default(0) int restaurantCount,
    @Default(CityStatus.comingSoon) CityStatus status,

    /// How much of the curated launch order still applies, 1 down to 0.
    ///
    /// Written by `recomputeAllRanks` and read-only here. The client
    /// must never recompute this curve: a second implementation drifts
    /// against the first, and the two disagreeing means the app says
    /// the list is still opening after the ranking has stopped
    /// protecting it, or the reverse.
    ///
    /// Defaults to 1 rather than 0 because an absent field means the
    /// recompute has never written one, which happens exactly when the
    /// city has no votes yet, which is when the curated order is fully
    /// in force. Defaulting to 0 would hide the opening-list line on
    /// launch day, the one day it is most true.
    @Default(1.0) double baselineWeight,
  }) = _City;

  const City._();

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  String get displayName => '$name, $state';
  bool get isLive => status == CityStatus.live;

  /// Whether the curated launch order still carries any weight.
  ///
  /// While this is true the city screen says so. When it goes false
  /// the line disappears and the list is ranked by locals alone.
  bool get isOpeningList => baselineWeight > 0;
}
