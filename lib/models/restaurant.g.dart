// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RestaurantLocation _$RestaurantLocationFromJson(Map<String, dynamic> json) =>
    _RestaurantLocation(
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$RestaurantLocationToJson(_RestaurantLocation instance) =>
    <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

_Restaurant _$RestaurantFromJson(Map<String, dynamic> json) => _Restaurant(
  id: json['id'] as String,
  cityId: json['cityId'] as String,
  name: json['name'] as String,
  cuisine: json['cuisine'] as String,
  imageUrl: json['imageUrl'] as String,
  description: json['description'] as String,
  rank: (json['rank'] as num).toInt(),
  voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  priceLevel: (json['priceLevel'] as num?)?.toDouble() ?? 2,
  locations:
      (json['locations'] as List<dynamic>?)
          ?.map((e) => RestaurantLocation.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  insiderTip: json['insiderTip'] as String?,
  whatToOrder: json['whatToOrder'] as String?,
  vibeTags:
      (json['vibeTags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  placeId: json['placeId'] as String?,
  isMobileVenue: json['isMobileVenue'] as bool? ?? false,
  openingHours:
      (json['openingHours'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
  rankScore: (json['rankScore'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$RestaurantToJson(_Restaurant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cityId': instance.cityId,
      'name': instance.name,
      'cuisine': instance.cuisine,
      'imageUrl': instance.imageUrl,
      'description': instance.description,
      'rank': instance.rank,
      'voteCount': instance.voteCount,
      'commentCount': instance.commentCount,
      'priceLevel': instance.priceLevel,
      'locations': instance.locations,
      'insiderTip': instance.insiderTip,
      'whatToOrder': instance.whatToOrder,
      'vibeTags': instance.vibeTags,
      'placeId': instance.placeId,
      'isMobileVenue': instance.isMobileVenue,
      'openingHours': instance.openingHours,
      'displayOrder': instance.displayOrder,
      'rankScore': instance.rankScore,
    };
