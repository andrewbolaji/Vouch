// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'restaurant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RestaurantLocation {

 String get name; String get address; double get latitude; double get longitude;
/// Create a copy of RestaurantLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestaurantLocationCopyWith<RestaurantLocation> get copyWith => _$RestaurantLocationCopyWithImpl<RestaurantLocation>(this as RestaurantLocation, _$identity);

  /// Serializes this RestaurantLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestaurantLocation&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,address,latitude,longitude);

@override
String toString() {
  return 'RestaurantLocation(name: $name, address: $address, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $RestaurantLocationCopyWith<$Res>  {
  factory $RestaurantLocationCopyWith(RestaurantLocation value, $Res Function(RestaurantLocation) _then) = _$RestaurantLocationCopyWithImpl;
@useResult
$Res call({
 String name, String address, double latitude, double longitude
});




}
/// @nodoc
class _$RestaurantLocationCopyWithImpl<$Res>
    implements $RestaurantLocationCopyWith<$Res> {
  _$RestaurantLocationCopyWithImpl(this._self, this._then);

  final RestaurantLocation _self;
  final $Res Function(RestaurantLocation) _then;

/// Create a copy of RestaurantLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? address = null,Object? latitude = null,Object? longitude = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [RestaurantLocation].
extension RestaurantLocationPatterns on RestaurantLocation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RestaurantLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RestaurantLocation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RestaurantLocation value)  $default,){
final _that = this;
switch (_that) {
case _RestaurantLocation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RestaurantLocation value)?  $default,){
final _that = this;
switch (_that) {
case _RestaurantLocation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String address,  double latitude,  double longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RestaurantLocation() when $default != null:
return $default(_that.name,_that.address,_that.latitude,_that.longitude);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String address,  double latitude,  double longitude)  $default,) {final _that = this;
switch (_that) {
case _RestaurantLocation():
return $default(_that.name,_that.address,_that.latitude,_that.longitude);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String address,  double latitude,  double longitude)?  $default,) {final _that = this;
switch (_that) {
case _RestaurantLocation() when $default != null:
return $default(_that.name,_that.address,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RestaurantLocation implements RestaurantLocation {
  const _RestaurantLocation({required this.name, required this.address, this.latitude = 0, this.longitude = 0});
  factory _RestaurantLocation.fromJson(Map<String, dynamic> json) => _$RestaurantLocationFromJson(json);

@override final  String name;
@override final  String address;
@override@JsonKey() final  double latitude;
@override@JsonKey() final  double longitude;

/// Create a copy of RestaurantLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestaurantLocationCopyWith<_RestaurantLocation> get copyWith => __$RestaurantLocationCopyWithImpl<_RestaurantLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestaurantLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestaurantLocation&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,address,latitude,longitude);

@override
String toString() {
  return 'RestaurantLocation(name: $name, address: $address, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$RestaurantLocationCopyWith<$Res> implements $RestaurantLocationCopyWith<$Res> {
  factory _$RestaurantLocationCopyWith(_RestaurantLocation value, $Res Function(_RestaurantLocation) _then) = __$RestaurantLocationCopyWithImpl;
@override @useResult
$Res call({
 String name, String address, double latitude, double longitude
});




}
/// @nodoc
class __$RestaurantLocationCopyWithImpl<$Res>
    implements _$RestaurantLocationCopyWith<$Res> {
  __$RestaurantLocationCopyWithImpl(this._self, this._then);

  final _RestaurantLocation _self;
  final $Res Function(_RestaurantLocation) _then;

/// Create a copy of RestaurantLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? address = null,Object? latitude = null,Object? longitude = null,}) {
  return _then(_RestaurantLocation(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$Restaurant {

 String get id; String get cityId; String get name; String get cuisine; String get imageUrl; String get description; int get rank; int get voteCount; double get priceLevel; List<RestaurantLocation> get locations; String? get insiderTip; String? get whatToOrder; List<String> get vibeTags;
/// Create a copy of Restaurant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestaurantCopyWith<Restaurant> get copyWith => _$RestaurantCopyWithImpl<Restaurant>(this as Restaurant, _$identity);

  /// Serializes this Restaurant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Restaurant&&(identical(other.id, id) || other.id == id)&&(identical(other.cityId, cityId) || other.cityId == cityId)&&(identical(other.name, name) || other.name == name)&&(identical(other.cuisine, cuisine) || other.cuisine == cuisine)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.voteCount, voteCount) || other.voteCount == voteCount)&&(identical(other.priceLevel, priceLevel) || other.priceLevel == priceLevel)&&const DeepCollectionEquality().equals(other.locations, locations)&&(identical(other.insiderTip, insiderTip) || other.insiderTip == insiderTip)&&(identical(other.whatToOrder, whatToOrder) || other.whatToOrder == whatToOrder)&&const DeepCollectionEquality().equals(other.vibeTags, vibeTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cityId,name,cuisine,imageUrl,description,rank,voteCount,priceLevel,const DeepCollectionEquality().hash(locations),insiderTip,whatToOrder,const DeepCollectionEquality().hash(vibeTags));

@override
String toString() {
  return 'Restaurant(id: $id, cityId: $cityId, name: $name, cuisine: $cuisine, imageUrl: $imageUrl, description: $description, rank: $rank, voteCount: $voteCount, priceLevel: $priceLevel, locations: $locations, insiderTip: $insiderTip, whatToOrder: $whatToOrder, vibeTags: $vibeTags)';
}


}

/// @nodoc
abstract mixin class $RestaurantCopyWith<$Res>  {
  factory $RestaurantCopyWith(Restaurant value, $Res Function(Restaurant) _then) = _$RestaurantCopyWithImpl;
@useResult
$Res call({
 String id, String cityId, String name, String cuisine, String imageUrl, String description, int rank, int voteCount, double priceLevel, List<RestaurantLocation> locations, String? insiderTip, String? whatToOrder, List<String> vibeTags
});




}
/// @nodoc
class _$RestaurantCopyWithImpl<$Res>
    implements $RestaurantCopyWith<$Res> {
  _$RestaurantCopyWithImpl(this._self, this._then);

  final Restaurant _self;
  final $Res Function(Restaurant) _then;

/// Create a copy of Restaurant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? cityId = null,Object? name = null,Object? cuisine = null,Object? imageUrl = null,Object? description = null,Object? rank = null,Object? voteCount = null,Object? priceLevel = null,Object? locations = null,Object? insiderTip = freezed,Object? whatToOrder = freezed,Object? vibeTags = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cityId: null == cityId ? _self.cityId : cityId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cuisine: null == cuisine ? _self.cuisine : cuisine // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,voteCount: null == voteCount ? _self.voteCount : voteCount // ignore: cast_nullable_to_non_nullable
as int,priceLevel: null == priceLevel ? _self.priceLevel : priceLevel // ignore: cast_nullable_to_non_nullable
as double,locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<RestaurantLocation>,insiderTip: freezed == insiderTip ? _self.insiderTip : insiderTip // ignore: cast_nullable_to_non_nullable
as String?,whatToOrder: freezed == whatToOrder ? _self.whatToOrder : whatToOrder // ignore: cast_nullable_to_non_nullable
as String?,vibeTags: null == vibeTags ? _self.vibeTags : vibeTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Restaurant].
extension RestaurantPatterns on Restaurant {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Restaurant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Restaurant() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Restaurant value)  $default,){
final _that = this;
switch (_that) {
case _Restaurant():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Restaurant value)?  $default,){
final _that = this;
switch (_that) {
case _Restaurant() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String cityId,  String name,  String cuisine,  String imageUrl,  String description,  int rank,  int voteCount,  double priceLevel,  List<RestaurantLocation> locations,  String? insiderTip,  String? whatToOrder,  List<String> vibeTags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Restaurant() when $default != null:
return $default(_that.id,_that.cityId,_that.name,_that.cuisine,_that.imageUrl,_that.description,_that.rank,_that.voteCount,_that.priceLevel,_that.locations,_that.insiderTip,_that.whatToOrder,_that.vibeTags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String cityId,  String name,  String cuisine,  String imageUrl,  String description,  int rank,  int voteCount,  double priceLevel,  List<RestaurantLocation> locations,  String? insiderTip,  String? whatToOrder,  List<String> vibeTags)  $default,) {final _that = this;
switch (_that) {
case _Restaurant():
return $default(_that.id,_that.cityId,_that.name,_that.cuisine,_that.imageUrl,_that.description,_that.rank,_that.voteCount,_that.priceLevel,_that.locations,_that.insiderTip,_that.whatToOrder,_that.vibeTags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String cityId,  String name,  String cuisine,  String imageUrl,  String description,  int rank,  int voteCount,  double priceLevel,  List<RestaurantLocation> locations,  String? insiderTip,  String? whatToOrder,  List<String> vibeTags)?  $default,) {final _that = this;
switch (_that) {
case _Restaurant() when $default != null:
return $default(_that.id,_that.cityId,_that.name,_that.cuisine,_that.imageUrl,_that.description,_that.rank,_that.voteCount,_that.priceLevel,_that.locations,_that.insiderTip,_that.whatToOrder,_that.vibeTags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Restaurant extends Restaurant {
  const _Restaurant({required this.id, required this.cityId, required this.name, required this.cuisine, required this.imageUrl, required this.description, required this.rank, this.voteCount = 0, this.priceLevel = 2, final  List<RestaurantLocation> locations = const [], this.insiderTip, this.whatToOrder, final  List<String> vibeTags = const []}): _locations = locations,_vibeTags = vibeTags,super._();
  factory _Restaurant.fromJson(Map<String, dynamic> json) => _$RestaurantFromJson(json);

@override final  String id;
@override final  String cityId;
@override final  String name;
@override final  String cuisine;
@override final  String imageUrl;
@override final  String description;
@override final  int rank;
@override@JsonKey() final  int voteCount;
@override@JsonKey() final  double priceLevel;
 final  List<RestaurantLocation> _locations;
@override@JsonKey() List<RestaurantLocation> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

@override final  String? insiderTip;
@override final  String? whatToOrder;
 final  List<String> _vibeTags;
@override@JsonKey() List<String> get vibeTags {
  if (_vibeTags is EqualUnmodifiableListView) return _vibeTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vibeTags);
}


/// Create a copy of Restaurant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestaurantCopyWith<_Restaurant> get copyWith => __$RestaurantCopyWithImpl<_Restaurant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestaurantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Restaurant&&(identical(other.id, id) || other.id == id)&&(identical(other.cityId, cityId) || other.cityId == cityId)&&(identical(other.name, name) || other.name == name)&&(identical(other.cuisine, cuisine) || other.cuisine == cuisine)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.voteCount, voteCount) || other.voteCount == voteCount)&&(identical(other.priceLevel, priceLevel) || other.priceLevel == priceLevel)&&const DeepCollectionEquality().equals(other._locations, _locations)&&(identical(other.insiderTip, insiderTip) || other.insiderTip == insiderTip)&&(identical(other.whatToOrder, whatToOrder) || other.whatToOrder == whatToOrder)&&const DeepCollectionEquality().equals(other._vibeTags, _vibeTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cityId,name,cuisine,imageUrl,description,rank,voteCount,priceLevel,const DeepCollectionEquality().hash(_locations),insiderTip,whatToOrder,const DeepCollectionEquality().hash(_vibeTags));

@override
String toString() {
  return 'Restaurant(id: $id, cityId: $cityId, name: $name, cuisine: $cuisine, imageUrl: $imageUrl, description: $description, rank: $rank, voteCount: $voteCount, priceLevel: $priceLevel, locations: $locations, insiderTip: $insiderTip, whatToOrder: $whatToOrder, vibeTags: $vibeTags)';
}


}

/// @nodoc
abstract mixin class _$RestaurantCopyWith<$Res> implements $RestaurantCopyWith<$Res> {
  factory _$RestaurantCopyWith(_Restaurant value, $Res Function(_Restaurant) _then) = __$RestaurantCopyWithImpl;
@override @useResult
$Res call({
 String id, String cityId, String name, String cuisine, String imageUrl, String description, int rank, int voteCount, double priceLevel, List<RestaurantLocation> locations, String? insiderTip, String? whatToOrder, List<String> vibeTags
});




}
/// @nodoc
class __$RestaurantCopyWithImpl<$Res>
    implements _$RestaurantCopyWith<$Res> {
  __$RestaurantCopyWithImpl(this._self, this._then);

  final _Restaurant _self;
  final $Res Function(_Restaurant) _then;

/// Create a copy of Restaurant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? cityId = null,Object? name = null,Object? cuisine = null,Object? imageUrl = null,Object? description = null,Object? rank = null,Object? voteCount = null,Object? priceLevel = null,Object? locations = null,Object? insiderTip = freezed,Object? whatToOrder = freezed,Object? vibeTags = null,}) {
  return _then(_Restaurant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cityId: null == cityId ? _self.cityId : cityId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cuisine: null == cuisine ? _self.cuisine : cuisine // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,voteCount: null == voteCount ? _self.voteCount : voteCount // ignore: cast_nullable_to_non_nullable
as int,priceLevel: null == priceLevel ? _self.priceLevel : priceLevel // ignore: cast_nullable_to_non_nullable
as double,locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<RestaurantLocation>,insiderTip: freezed == insiderTip ? _self.insiderTip : insiderTip // ignore: cast_nullable_to_non_nullable
as String?,whatToOrder: freezed == whatToOrder ? _self.whatToOrder : whatToOrder // ignore: cast_nullable_to_non_nullable
as String?,vibeTags: null == vibeTags ? _self._vibeTags : vibeTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
