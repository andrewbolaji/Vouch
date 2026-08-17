import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/repositories/membership_repository.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/services/revenue_cat_service.dart';

void main() {
  _pendingTests();
  group('MembershipProvider', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      RevenueCatService.resetSimulatedState();
    });

    test('starts at free tier', () {
      final provider = MembershipProvider();
      expect(
        provider.currentTier,
        MembershipTier.free,
      );
      expect(provider.tierName, 'Free');
    });

    test('free tier has correct permissions', () {
      final provider = MembershipProvider();
      expect(provider.canViewTop10, isFalse);
      expect(provider.canSaveRestaurants, isFalse);
      expect(provider.canViewInsiderTips, isFalse);
      expect(provider.hasInsiderBadge, isFalse);
    });

    test('localsPass tier permissions', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      expect(provider.canViewTop10, isTrue);
      expect(provider.canSaveRestaurants, isTrue);
      expect(provider.canViewInsiderTips, isFalse);
      expect(provider.hasInsiderBadge, isFalse);
      expect(provider.tierName, 'Locals Pass');
    });

    test('cityInsider tier permissions', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(
        MembershipTier.cityInsider,
      );

      expect(provider.canViewTop10, isTrue);
      expect(provider.canSaveRestaurants, isTrue);
      expect(provider.canViewInsiderTips, isTrue);
      expect(provider.hasInsiderBadge, isTrue);
      expect(provider.tierName, 'City Insider');
    });

    test('toggleBillingCycle flips state', () {
      final provider = MembershipProvider();
      expect(provider.isYearlyBilling, isFalse);

      provider.toggleBillingCycle();
      expect(provider.isYearlyBilling, isTrue);

      provider.toggleBillingCycle();
      expect(provider.isYearlyBilling, isFalse);
    });

    test('notifies listeners on purchase', () async {
      final provider = MembershipProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.purchaseTier(MembershipTier.localsPass);
      expect(notified, isTrue);
    });

    test('notifies listeners on billing toggle', () {
      final provider = MembershipProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.toggleBillingCycle();
      expect(notified, isTrue);
    });
  });

  group('MembershipProvider simulate path', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      RevenueCatService.resetSimulatedState();
    });

    test('kSimulatePurchases is true in the test environment', () {
      expect(kSimulatePurchases, isTrue);
    });

    test('simulate purchase localsPass grants locals_pass entitlement',
        () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      // Restore on a fresh provider picks up simulated entitlements
      final provider2 = MembershipProvider();
      await provider2.restorePurchases();
      expect(provider2.currentTier, MembershipTier.localsPass);
    });

    test('simulate purchase cityInsider grants both entitlements', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.cityInsider);

      final provider2 = MembershipProvider();
      await provider2.restorePurchases();
      expect(provider2.currentTier, MembershipTier.cityInsider);
    });

    test('refreshEntitlements reflects simulated state', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      final provider2 = MembershipProvider();
      await provider2.refreshEntitlements();
      expect(provider2.currentTier, MembershipTier.localsPass);
    });

    test('logOut clears simulated entitlements', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.cityInsider);

      await RevenueCatService.logOut();

      final provider2 = MembershipProvider();
      await provider2.refreshEntitlements();
      expect(provider2.currentTier, MembershipTier.free);
    });
  });
}

// ====================================================================
// Pending confirmation: paid according to RevenueCat, not yet
// according to the custom claim firestore.rules actually enforces.
//
// simulatePurchases: false is required to reach this at all.
// kSimulatePurchases is a compile-time const tied to kDebugMode, and
// tests run in debug, so without the seam every one of these paths is
// unreachable and the behaviour ships unproven.
// ====================================================================

void _pendingTests() {
  group('MembershipProvider pending confirmation', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      RevenueCatService.resetSimulatedState();
    });

    AuthService signedInMock({String? claim}) {
      final auth = AuthService.mock(
        initialUser: const AuthUser(uid: 'u1', emailVerified: true),
      )..setMockMembershipClaim(claim);
      return auth;
    }

    test('an entitlement with no claim yet is pending, and stays locked',
        () async {
      final auth = signedInMock();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);

      await provider.refreshEntitlements();

      expect(provider.isAwaitingConfirmation, isTrue);
      expect(provider.currentTier, MembershipTier.free);
      // Locked, not optimistically unlocked: firestore.rules gates on
      // the claim, so unlocking here would produce denied reads.
      expect(provider.canViewInsiderTips, isFalse);
      expect(provider.canViewTop10, isFalse);
    });

    test('a claim that agrees resolves to paid and clears pending',
        () async {
      final auth = signedInMock(claim: 'cityInsider');
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);

      await provider.refreshEntitlements();

      expect(provider.isAwaitingConfirmation, isFalse);
      expect(provider.currentTier, MembershipTier.cityInsider);
      expect(provider.canViewInsiderTips, isTrue);
    });

    test('no entitlement means nothing pending', () async {
      final auth = signedInMock();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );

      await provider.refreshEntitlements();

      expect(provider.isAwaitingConfirmation, isFalse);
      expect(provider.currentTier, MembershipTier.free);
    });

    // The ephemerality proof. A stored pending flag would strand a
    // user who backgrounded the app mid-purchase in a confirming
    // state nothing re-evaluates. A fresh provider is what a relaunch
    // produces, and it must land on the real tier.
    test('a relaunch out of pending resolves to the real tier', () async {
      final auth = signedInMock();
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);

      final beforeRelaunch = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await beforeRelaunch.refreshEntitlements();
      expect(beforeRelaunch.isAwaitingConfirmation, isTrue);

      // The webhook lands while the app is closed.
      auth.setMockMembershipClaim('cityInsider');

      // Relaunch: a new provider carrying nothing forward.
      final afterRelaunch = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await afterRelaunch.refreshEntitlements();

      expect(afterRelaunch.isAwaitingConfirmation, isFalse);
      expect(afterRelaunch.currentTier, MembershipTier.cityInsider);
    });

    test('a relaunch still pending stays pending, not silently paid',
        () async {
      final auth = signedInMock();
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);

      final afterRelaunch = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await afterRelaunch.refreshEntitlements();

      expect(afterRelaunch.isAwaitingConfirmation, isTrue);
      expect(afterRelaunch.currentTier, MembershipTier.free);
    });

    test('retryConfirmation clears pending once the claim lands',
        () async {
      final auth = signedInMock();
      final repo = _FakeMembershipRepository();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
        membershipRepo: repo,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);
      await provider.refreshEntitlements();
      expect(provider.isAwaitingConfirmation, isTrue);

      auth.setMockMembershipClaim('cityInsider');
      await provider.retryConfirmation();

      expect(provider.isAwaitingConfirmation, isFalse);
      expect(provider.currentTier, MembershipTier.cityInsider);
    });

    // Finding 5. The button used to re-read a claim that nothing was
    // going to change: the webhook is the only writer of that claim,
    // and the state being retried is the state where the webhook
    // never arrived. These pin the repair path instead.
    test('retryConfirmation asks the server to reconcile first',
        () async {
      final auth = signedInMock();
      final repo = _FakeMembershipRepository();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
        membershipRepo: repo,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);
      await provider.refreshEntitlements();

      // The webhook never landed, so the claim is still absent. The
      // reconcile call is what sets it, which is the whole point.
      repo.onReconcile = () => auth.setMockMembershipClaim('cityInsider');
      await provider.retryConfirmation();

      expect(repo.calls, 1);
      expect(provider.isAwaitingConfirmation, isFalse);
      expect(provider.currentTier, MembershipTier.cityInsider);
    });

    test('a failed reconcile leaves the user pending, not crashed',
        () async {
      // Swallowed on purpose. The refresh still runs, so the outcome
      // is the state the pending screen already describes, and there
      // is nothing more useful to tell somebody whose purchase is
      // still not visible.
      final auth = signedInMock();
      final repo = _FakeMembershipRepository()..throwOnReconcile = true;
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
        membershipRepo: repo,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);
      await provider.refreshEntitlements();

      await provider.retryConfirmation();

      expect(repo.calls, 1);
      expect(provider.isAwaitingConfirmation, isTrue);
      expect(provider.currentTier, MembershipTier.free);
    });

    test('nothing is reconciled when nothing is pending', () async {
      final auth = signedInMock(claim: 'cityInsider');
      final repo = _FakeMembershipRepository();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
        membershipRepo: repo,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);
      await provider.refreshEntitlements();
      expect(provider.isAwaitingConfirmation, isFalse);

      await provider.retryConfirmation();

      // A daily server cap sits behind this call, and spending it on
      // a user who has no problem would spend it for the one who does.
      expect(repo.calls, 0);
    });

    test('a claim for a different tier does not confirm', () async {
      final auth = signedInMock(claim: 'localsPass');
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );
      await RevenueCatService.purchase(RevenueCatConfig.cityInsiderMonthly);

      await provider.refreshEntitlements();

      expect(provider.isAwaitingConfirmation, isTrue);
      expect(provider.currentTier, MembershipTier.free);
    });

    // The slow path, deliberately: the real poll budget is 5 tries
    // with a 2 second gap, so this exercises the exhaustion branch
    // end to end rather than short-cutting to refreshEntitlements.
    test('a purchase whose claim never lands ends pending, not paid',
        () async {
      final auth = signedInMock();
      final provider = MembershipProvider(
        authService: auth,
        simulatePurchases: false,
      );

      final result = await provider.purchaseTier(MembershipTier.cityInsider);

      expect(result, PurchaseResult.success);
      expect(provider.isAwaitingConfirmation, isTrue);
      expect(provider.currentTier, MembershipTier.free);
      expect(provider.canViewInsiderTips, isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

/// Implements the repository rather than extending it, because the
/// real constructor reaches FirebaseAuth.instance, which does not
/// exist in a unit test.
class _FakeMembershipRepository implements MembershipRepository {
  int calls = 0;
  bool throwOnReconcile = false;
  void Function()? onReconcile;

  @override
  Future<String> reconcile() async {
    calls++;
    if (throwOnReconcile) throw Exception('reconcile unavailable');
    onReconcile?.call();
    return 'cityInsider';
  }
}
