// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'insider_notes.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InsiderNotes {

 String get restaurantId; String? get whatToOrder; String? get insiderTip;
/// Create a copy of InsiderNotes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InsiderNotesCopyWith<InsiderNotes> get copyWith => _$InsiderNotesCopyWithImpl<InsiderNotes>(this as InsiderNotes, _$identity);

  /// Serializes this InsiderNotes to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InsiderNotes&&(identical(other.restaurantId, restaurantId) || other.restaurantId == restaurantId)&&(identical(other.whatToOrder, whatToOrder) || other.whatToOrder == whatToOrder)&&(identical(other.insiderTip, insiderTip) || other.insiderTip == insiderTip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restaurantId,whatToOrder,insiderTip);

@override
String toString() {
  return 'InsiderNotes(restaurantId: $restaurantId, whatToOrder: $whatToOrder, insiderTip: $insiderTip)';
}


}

/// @nodoc
abstract mixin class $InsiderNotesCopyWith<$Res>  {
  factory $InsiderNotesCopyWith(InsiderNotes value, $Res Function(InsiderNotes) _then) = _$InsiderNotesCopyWithImpl;
@useResult
$Res call({
 String restaurantId, String? whatToOrder, String? insiderTip
});




}
/// @nodoc
class _$InsiderNotesCopyWithImpl<$Res>
    implements $InsiderNotesCopyWith<$Res> {
  _$InsiderNotesCopyWithImpl(this._self, this._then);

  final InsiderNotes _self;
  final $Res Function(InsiderNotes) _then;

/// Create a copy of InsiderNotes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? restaurantId = null,Object? whatToOrder = freezed,Object? insiderTip = freezed,}) {
  return _then(_self.copyWith(
restaurantId: null == restaurantId ? _self.restaurantId : restaurantId // ignore: cast_nullable_to_non_nullable
as String,whatToOrder: freezed == whatToOrder ? _self.whatToOrder : whatToOrder // ignore: cast_nullable_to_non_nullable
as String?,insiderTip: freezed == insiderTip ? _self.insiderTip : insiderTip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InsiderNotes].
extension InsiderNotesPatterns on InsiderNotes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InsiderNotes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InsiderNotes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InsiderNotes value)  $default,){
final _that = this;
switch (_that) {
case _InsiderNotes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InsiderNotes value)?  $default,){
final _that = this;
switch (_that) {
case _InsiderNotes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String restaurantId,  String? whatToOrder,  String? insiderTip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InsiderNotes() when $default != null:
return $default(_that.restaurantId,_that.whatToOrder,_that.insiderTip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String restaurantId,  String? whatToOrder,  String? insiderTip)  $default,) {final _that = this;
switch (_that) {
case _InsiderNotes():
return $default(_that.restaurantId,_that.whatToOrder,_that.insiderTip);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String restaurantId,  String? whatToOrder,  String? insiderTip)?  $default,) {final _that = this;
switch (_that) {
case _InsiderNotes() when $default != null:
return $default(_that.restaurantId,_that.whatToOrder,_that.insiderTip);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InsiderNotes implements InsiderNotes {
  const _InsiderNotes({required this.restaurantId, this.whatToOrder, this.insiderTip});
  factory _InsiderNotes.fromJson(Map<String, dynamic> json) => _$InsiderNotesFromJson(json);

@override final  String restaurantId;
@override final  String? whatToOrder;
@override final  String? insiderTip;

/// Create a copy of InsiderNotes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InsiderNotesCopyWith<_InsiderNotes> get copyWith => __$InsiderNotesCopyWithImpl<_InsiderNotes>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InsiderNotesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InsiderNotes&&(identical(other.restaurantId, restaurantId) || other.restaurantId == restaurantId)&&(identical(other.whatToOrder, whatToOrder) || other.whatToOrder == whatToOrder)&&(identical(other.insiderTip, insiderTip) || other.insiderTip == insiderTip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restaurantId,whatToOrder,insiderTip);

@override
String toString() {
  return 'InsiderNotes(restaurantId: $restaurantId, whatToOrder: $whatToOrder, insiderTip: $insiderTip)';
}


}

/// @nodoc
abstract mixin class _$InsiderNotesCopyWith<$Res> implements $InsiderNotesCopyWith<$Res> {
  factory _$InsiderNotesCopyWith(_InsiderNotes value, $Res Function(_InsiderNotes) _then) = __$InsiderNotesCopyWithImpl;
@override @useResult
$Res call({
 String restaurantId, String? whatToOrder, String? insiderTip
});




}
/// @nodoc
class __$InsiderNotesCopyWithImpl<$Res>
    implements _$InsiderNotesCopyWith<$Res> {
  __$InsiderNotesCopyWithImpl(this._self, this._then);

  final _InsiderNotes _self;
  final $Res Function(_InsiderNotes) _then;

/// Create a copy of InsiderNotes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? restaurantId = null,Object? whatToOrder = freezed,Object? insiderTip = freezed,}) {
  return _then(_InsiderNotes(
restaurantId: null == restaurantId ? _self.restaurantId : restaurantId // ignore: cast_nullable_to_non_nullable
as String,whatToOrder: freezed == whatToOrder ? _self.whatToOrder : whatToOrder // ignore: cast_nullable_to_non_nullable
as String?,insiderTip: freezed == insiderTip ? _self.insiderTip : insiderTip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
