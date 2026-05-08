import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();

  static const String _prefKeyRankingAlerts =
      'notifications_ranking_alerts';
  static const String _prefKeyNewCities =
      'notifications_new_cities';
  static const String _prefKeyWeeklyDigest =
      'notifications_weekly_digest';

  static Future<void> initialize() async {
    // TODO(vouch): Initialize FCM when Firebase is configured.
    debugPrint(
      'NotificationService: initialized (local-only mode)',
    );
  }

  static Future<bool> getRankingAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyRankingAlerts) ?? true;
  }

  static Future<void> setRankingAlerts({
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyRankingAlerts, value);
  }

  static Future<bool> getNewCityAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyNewCities) ?? true;
  }

  static Future<void> setNewCityAlerts({
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyNewCities, value);
  }

  static Future<bool> getWeeklyDigest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyWeeklyDigest) ?? false;
  }

  static Future<void> setWeeklyDigest({
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyWeeklyDigest, value);
  }
}
