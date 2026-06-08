// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insider_notes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InsiderNotes _$InsiderNotesFromJson(Map<String, dynamic> json) =>
    _InsiderNotes(
      restaurantId: json['restaurantId'] as String,
      whatToOrder: json['whatToOrder'] as String?,
      insiderTip: json['insiderTip'] as String?,
    );

Map<String, dynamic> _$InsiderNotesToJson(_InsiderNotes instance) =>
    <String, dynamic>{
      'restaurantId': instance.restaurantId,
      'whatToOrder': instance.whatToOrder,
      'insiderTip': instance.insiderTip,
    };
