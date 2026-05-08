import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/services/auth_service.dart';

/// Shared test app builder with real providers.
///
/// Uses real providers (not mocks) because the
/// interaction tests verify end-to-end behavior
/// through the actual provider layer. Mocks are used
/// only where we need to override specific state
/// (e.g., membership tier).
Widget buildTestApp(
  Widget child, {
  MembershipProvider? membershipOverride,
  AuthService? authOverride,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState()),
      ChangeNotifierProvider(
        create: (_) =>
            membershipOverride ?? MembershipProvider(),
      ),
      ChangeNotifierProvider(create: (_) => SavedProvider()),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(),
      ),
      ChangeNotifierProvider(
        create: (_) => authOverride ?? AuthService.mock(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

/// Duration to wait for AppState seed data to load.
const seedLoadDuration = Duration(milliseconds: 700);

/// Pumps the widget tree past the AppState seed load
/// delay, then settles remaining frames. Use this
/// instead of pumpAndSettle(seedLoadDuration) when
/// pumpAndSettle enters an infinite loop due to
/// ChangeNotifier async constructors.
Future<void> pumpPastLoad(WidgetTester tester) async {
  // Pump past the 500ms Future.delayed in AppState
  await tester.pump(seedLoadDuration);
  // Pump a few more frames to settle rebuilds
  await tester.pump();
  await tester.pump();
}
