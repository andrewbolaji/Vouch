import 'package:freezed_annotation/freezed_annotation.dart';

part 'city.freezed.dart';
part 'city.g.dart';

@freezed
abstract class City with _$City {
  const factory City({
    required String id,
    required String name,
    required String state,
    required String imageUrl,
    required String description,
    @Default(0) int restaurantCount,
  }) = _City;

  const City._();

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  String get displayName => '$name, $state';
}
