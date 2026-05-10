enum SuggestionType { newRestaurant, correction, newCity, general }

const int kDailySuggestionCap = 1;

class Suggestion {

  const Suggestion({
    required this.id,
    required this.userId,
    required this.type,
    required this.text,
    required this.createdAt, this.cityId,
  });
  final String id;
  final String userId;
  final SuggestionType type;
  final String text;
  final String? cityId;
  final DateTime createdAt;
}
