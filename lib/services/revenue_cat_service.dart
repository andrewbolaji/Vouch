import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// True only in debug builds. The compiler tree-shakes this branch
/// in release mode, so a release build cannot take the simulate path.
const bool kSimulatePurchases = kDebugMode;

/// RevenueCat product and entitlement identifiers.
/// PLACEHOLDER values: replace with your RevenueCat dashboard configuration.
class RevenueCatConfig {
  RevenueCatConfig._();

  // PLACEHOLDER: Replace with your RevenueCat public SDK keys.
  static const String appleApiKey = 'appl_JbjVMnHeyNDTQSqfHUzlDDvOHXi';
  static const String googleApiKey = 'goog_VOUCH_ANDROID_API_KEY';

  // Entitlement identifiers (must match RevenueCat dashboard).
  static const String localsPassEntitlement = 'locals_pass';
  static const String cityInsiderEntitlement = 'city_insider';

  // PLACEHOLDER: Must match App Store Connect / Google Play product IDs.
  static const String localsPassMonthly = 'com.vouch.app.locals_pass.monthly';
  static const String localsPassYearly = 'com.vouch.app.locals_pass.yearly';
  static const String cityInsiderMonthly =
      'com.vouch.app.city_insider.monthly';
  static const String cityInsiderYearly = 'com.vouch.app.city_insider.yearly';
}

/// Wraps RevenueCat SDK interactions.
///
/// In debug builds ([kSimulatePurchases] = true), all methods use an
/// in-memory simulation so paid flows can be tested without StoreKit
/// products or a configured RevenueCat dashboard.
class RevenueCatService {
  RevenueCatService._();

  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  // In-memory entitlements for the simulate path (debug only).
  static final Set<String> _simulatedEntitlements = {};

  @visibleForTesting
  static void resetSimulatedState() {
    _simulatedEntitlements.clear();
    _isConfigured = false;
  }

  /// Call once at app startup (before any logIn/purchase calls).
  static Future<void> configure() async {
    if (kSimulatePurchases) {
      _isConfigured = true;
      debugPrint('RevenueCatService: configured (simulate mode)');
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? RevenueCatConfig.appleApiKey
          : RevenueCatConfig.googleApiKey;
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isConfigured = true;
    } on Exception catch (e) {
      debugPrint('RevenueCatService: configure failed: $e');
    }
  }

  /// Identify the user to RevenueCat with their Firebase UID.
  /// Call on sign-in and on app launch when already signed in.
  static Future<void> logIn(String userId) async {
    if (kSimulatePurchases) {
      debugPrint('RevenueCatService: logIn simulate (uid=$userId)');
      return;
    }

    try {
      await Purchases.logIn(userId);
    } on Exception catch (e) {
      debugPrint('RevenueCatService: logIn failed: $e');
    }
  }

  /// Reset RevenueCat to anonymous on sign-out.
  static Future<void> logOut() async {
    if (kSimulatePurchases) {
      _simulatedEntitlements.clear();
      debugPrint('RevenueCatService: logOut simulate');
      return;
    }

    try {
      await Purchases.logOut();
    } on Exception catch (e) {
      debugPrint('RevenueCatService: logOut failed: $e');
    }
  }

  /// Returns the user's current active entitlements.
  static Future<Set<String>> getActiveEntitlements() async {
    if (kSimulatePurchases) {
      return Set<String>.of(_simulatedEntitlements);
    }

    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.keys.toSet();
    } on Exception catch (e) {
      debugPrint('RevenueCatService: getActiveEntitlements failed: $e');
      return {};
    }
  }

  /// Purchase a specific product by its store product ID.
  static Future<bool> purchase(String productId) async {
    if (kSimulatePurchases) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (productId.contains('city_insider')) {
        _simulatedEntitlements
          ..add(RevenueCatConfig.cityInsiderEntitlement)
          ..add(RevenueCatConfig.localsPassEntitlement);
      } else if (productId.contains('locals_pass')) {
        _simulatedEntitlements.add(RevenueCatConfig.localsPassEntitlement);
      }
      return true;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? [];
      for (final pkg in packages) {
        if (pkg.storeProduct.identifier == productId) {
          final result = await Purchases.purchase(
            PurchaseParams.package(pkg),
          );
          return result.customerInfo.entitlements.active.isNotEmpty;
        }
      }
      debugPrint('RevenueCatService: product $productId not found');
      return false;
    } on Exception catch (e) {
      debugPrint('RevenueCatService: purchase failed: $e');
      return false;
    }
  }

  /// Restore previous purchases.
  static Future<Set<String>> restorePurchases() async {
    if (kSimulatePurchases) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return Set<String>.of(_simulatedEntitlements);
    }

    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.keys.toSet();
    } on Exception catch (e) {
      debugPrint('RevenueCatService: restorePurchases failed: $e');
      return {};
    }
  }
}
