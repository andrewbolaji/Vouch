// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfile {

 String get id; String get displayName; String get email;@TimestampConverter() DateTime get createdAt;@TimestampConverter() DateTime get lastActiveAt; String? get photoUrl; String get membershipTier; List<String> get savedRestaurantIds;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastActiveAt, lastActiveAt) || other.lastActiveAt == lastActiveAt)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.membershipTier, membershipTier) || other.membershipTier == membershipTier)&&const DeepCollectionEquality().equals(other.savedRestaurantIds, savedRestaurantIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,email,createdAt,lastActiveAt,photoUrl,membershipTier,const DeepCollectionEquality().hash(savedRestaurantIds));

@override
String toString() {
  return 'UserProfile(id: $id, displayName: $displayName, email: $email, createdAt: $createdAt, lastActiveAt: $lastActiveAt, photoUrl: $photoUrl, membershipTier: $membershipTier, savedRestaurantIds: $savedRestaurantIds)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String email,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime lastActiveAt, String? photoUrl, String membershipTier, List<String> savedRestaurantIds
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? email = null,Object? createdAt = null,Object? lastActiveAt = null,Object? photoUrl = freezed,Object? membershipTier = null,Object? savedRestaurantIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastActiveAt: null == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,membershipTier: null == membershipTier ? _self.membershipTier : membershipTier // ignore: cast_nullable_to_non_nullable
as String,savedRestaurantIds: null == savedRestaurantIds ? _self.savedRestaurantIds : savedRestaurantIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String email, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime lastActiveAt,  String? photoUrl,  String membershipTier,  List<String> savedRestaurantIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.displayName,_that.email,_that.createdAt,_that.lastActiveAt,_that.photoUrl,_that.membershipTier,_that.savedRestaurantIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String email, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime lastActiveAt,  String? photoUrl,  String membershipTier,  List<String> savedRestaurantIds)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.displayName,_that.email,_that.createdAt,_that.lastActiveAt,_that.photoUrl,_that.membershipTier,_that.savedRestaurantIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String email, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime lastActiveAt,  String? photoUrl,  String membershipTier,  List<String> savedRestaurantIds)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.displayName,_that.email,_that.createdAt,_that.lastActiveAt,_that.photoUrl,_that.membershipTier,_that.savedRestaurantIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfile implements UserProfile {
  const _UserProfile({required this.id, required this.displayName, required this.email, @TimestampConverter() required this.createdAt, @TimestampConverter() required this.lastActiveAt, this.photoUrl, this.membershipTier = 'free', final  List<String> savedRestaurantIds = const []}): _savedRestaurantIds = savedRestaurantIds;
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String email;
@override@TimestampConverter() final  DateTime createdAt;
@override@TimestampConverter() final  DateTime lastActiveAt;
@override final  String? photoUrl;
@override@JsonKey() final  String membershipTier;
 final  List<String> _savedRestaurantIds;
@override@JsonKey() List<String> get savedRestaurantIds {
  if (_savedRestaurantIds is EqualUnmodifiableListView) return _savedRestaurantIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_savedRestaurantIds);
}


/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastActiveAt, lastActiveAt) || other.lastActiveAt == lastActiveAt)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.membershipTier, membershipTier) || other.membershipTier == membershipTier)&&const DeepCollectionEquality().equals(other._savedRestaurantIds, _savedRestaurantIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,email,createdAt,lastActiveAt,photoUrl,membershipTier,const DeepCollectionEquality().hash(_savedRestaurantIds));

@override
String toString() {
  return 'UserProfile(id: $id, displayName: $displayName, email: $email, createdAt: $createdAt, lastActiveAt: $lastActiveAt, photoUrl: $photoUrl, membershipTier: $membershipTier, savedRestaurantIds: $savedRestaurantIds)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String email,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime lastActiveAt, String? photoUrl, String membershipTier, List<String> savedRestaurantIds
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? email = null,Object? createdAt = null,Object? lastActiveAt = null,Object? photoUrl = freezed,Object? membershipTier = null,Object? savedRestaurantIds = null,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastActiveAt: null == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,membershipTier: null == membershipTier ? _self.membershipTier : membershipTier // ignore: cast_nullable_to_non_nullable
as String,savedRestaurantIds: null == savedRestaurantIds ? _self._savedRestaurantIds : savedRestaurantIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
