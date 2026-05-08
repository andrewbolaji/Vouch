import 'package:flutter/foundation.dart';

/// RevenueCat product identifiers.
/// Update these to match your RevenueCat dashboard products.
class RevenueCatConfig {
  RevenueCatConfig._();

  // TODO(vouch): Replace with your actual RevenueCat API keys.
  static const String appleApiKey = 'appl_YOUR_API_KEY';
  static const String googleApiKey = 'goog_YOUR_API_KEY';

  // Entitlement identifiers (set these in your RevenueCat dashboard)
  static const String localsPassEntitlement = 'locals_pass';
  static const String cityInsiderEntitlement = 'city_insider';

  // Product identifiers
  static const String localsPassMonthly = 'vouch_locals_pass_monthly';
  static const String localsPassYearly = 'vouch_locals_pass_yearly';
  static const String cityInsiderMonthly = 'vouch_city_insider_monthly';
  static const String cityInsiderYearly = 'vouch_city_insider_yearly';
}

/// Wraps RevenueCat SDK interactions.
///
/// To activate:
/// 1. Add `purchases_flutter: ^8.0.0` to pubspec.yaml
/// 2. Create products in App Store Connect / Google Play Console
/// 3. Configure them in your RevenueCat dashboard
/// 4. Replace the API keys above
/// 5. Uncomment the Purchases SDK calls below
class RevenueCatService {
  RevenueCatService._();

  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  /// Call once at app startup.
  static Future<void> configure({required String userId}) async {
    // TODO(vouch): Uncomment when purchases_flutter is added.
    //
    // await Purchases.setLogLevel(LogLevel.debug);
    // PurchasesConfiguration configuration;
    // if (defaultTargetPlatform == TargetPlatform.iOS) {
    //   configuration = PurchasesConfiguration(RevenueCatConfig.appleApiKey);
    // } else {
    //   configuration = PurchasesConfiguration(RevenueCatConfig.googleApiKey);
    // }
    // configuration.appUserID = userId;
    // await Purchases.configure(configuration);

    _isConfigured = true;
    debugPrint('RevenueCatService: configured (mock mode)');
  }

  /// Returns the user's current active entitlements.
  static Future<Set<String>> getActiveEntitlements() async {
    // TODO(vouch): Uncomment when purchases_flutter is added.
    //
    // try {
    //   final customerInfo = await Purchases.getCustomerInfo();
    //   return customerInfo.entitlements.active.keys.toSet();
    // } catch (e) {
    //   debugPrint('RevenueCat error: $e');
    //   return {};
    // }

    return {};
  }

  /// Purchase a specific product.
  static Future<bool> purchase(String productId) async {
    // TODO(vouch): Uncomment when purchases_flutter is added.
    //
    // try {
    //   final offerings = await Purchases.getOfferings();
    //   final packages = offerings.current?.availablePackages ?? [];
    //   final package = packages.firstWhere(
    //     (p) => p.storeProduct.identifier == productId,
    //   );
    //   final result = await Purchases.purchasePackage(package);
    //   return result.customerInfo.entitlements.active.isNotEmpty;
    // } catch (e) {
    //   debugPrint('RevenueCat purchase error: $e');
    //   return false;
    // }

    // Mock: always succeed
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Restore previous purchases.
  static Future<Set<String>> restorePurchases() async {
    // TODO(vouch): Uncomment when purchases_flutter is added.
    //
    // try {
    //   final customerInfo = await Purchases.restorePurchases();
    //   return customerInfo.entitlements.active.keys.toSet();
    // } catch (e) {
    //   debugPrint('RevenueCat restore error: $e');
    //   return {};
    // }

    await Future<void>.delayed(const Duration(seconds: 1));
    return {};
  }
}
