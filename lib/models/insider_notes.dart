import 'package:freezed_annotation/freezed_annotation.dart';

part 'insider_notes.freezed.dart';
part 'insider_notes.g.dart';

/// Insider notes stored in a subcollection under each restaurant.
/// This separates premium content from the public restaurant document.
@freezed
abstract class InsiderNotes with _$InsiderNotes {
  const factory InsiderNotes({
    required String restaurantId,
    String? whatToOrder,
    String? insiderTip,
  }) = _InsiderNotes;

  factory InsiderNotes.fromJson(Map<String, dynamic> json) =>
      _$InsiderNotesFromJson(json);
}
