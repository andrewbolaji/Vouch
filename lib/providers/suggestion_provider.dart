import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/models.dart';

class SuggestionProvider extends ChangeNotifier {
  SuggestionProvider() {
    unawaited(_loadDailyCounts());
  }

  static const String _prefKey = 'suggestion_daily_counts';

  final List<Suggestion> _suggestions = [];
  Map<String, int> _dailyCounts = {};

  List<Suggestion> get suggestions =>
      List.unmodifiable(_suggestions);

  int get todayCount {
    final today = _todayKey();
    return _dailyCounts[today] ?? 0;
  }

  bool get canSubmitToday => todayCount < kDailySuggestionCap;

  int get remainingToday => kDailySuggestionCap - todayCount;

  bool submitSuggestion({
    required SuggestionType type,
    required String text,
    String? cityId,
  }) {
    if (!canSubmitToday) return false;

    final suggestion = Suggestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'anonymous',
      type: type,
      text: text,
      cityId: cityId,
      createdAt: DateTime.now(),
    );

    _suggestions.add(suggestion);
    final today = _todayKey();
    _dailyCounts[today] = (_dailyCounts[today] ?? 0) + 1;
    notifyListeners();
    unawaited(_saveDailyCounts());
    return true;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDailyCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _dailyCounts = decoded.map(
          (k, v) => MapEntry(k, v as int),
        );
      }
    } on Exception catch (e) {
      debugPrint(
        'SuggestionProvider: failed to load counts: $e',
      );
    }
  }

  Future<void> _saveDailyCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(_dailyCounts),
      );
    } on Exception catch (e) {
      debugPrint(
        'SuggestionProvider: failed to save counts: $e',
      );
    }
  }
}
