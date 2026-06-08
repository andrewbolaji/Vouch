// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_City _$CityFromJson(Map<String, dynamic> json) => _City(
  id: json['id'] as String,
  name: json['name'] as String,
  state: json['state'] as String,
  imageUrl: json['imageUrl'] as String,
  description: json['description'] as String,
  restaurantCount: (json['restaurantCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CityToJson(_City instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'state': instance.state,
  'imageUrl': instance.imageUrl,
  'description': instance.description,
  'restaurantCount': instance.restaurantCount,
};
