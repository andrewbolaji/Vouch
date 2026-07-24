import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

/// Set up the golden test environment.
///
/// Anton and Archivo TTFs are registered in pubspec.yaml under fonts:,
/// so they are included in the asset bundle. google_fonts detects a
/// matching family name in the bundle and uses it without fetching.
/// Runtime fetching is disabled so tests never attempt network
/// access.
///
/// Baselines are validated on this machine (macOS arm64). Flutter goldens
/// can produce pixel differences across OS, architecture, or Flutter
/// version. This is a known limitation, documented here.
Future<void> setUpGoldens() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // flutter_cache_manager (used by CachedNetworkImage in RestaurantImage)
  // calls path_provider to find a cache directory. That platform channel
  // has no implementation in a headless `flutter test`, so it throws
  // MissingPluginException. Answer the channel with a real temp directory
  // so the widget tree renders instead of crashing.
  final cacheDir = Directory.systemTemp.createTempSync('vouch_goldens');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (methodCall) async => cacheDir.path,
  );

  // flutter_cache_manager keeps cache metadata in a sqflite database, whose
  // platform channel is absent headless. Back it with the FFI factory (real
  // SQLite, no plugin) so the cache layer initializes instead of throwing
  // "databaseFactory not initialized". The cache starts empty, so the network
  // fetch returns headless and RestaurantImage renders its placeholder.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Fixed surface size for deterministic golden renders (iPhone 14 Pro).
const goldenSurfaceSize = Size(390, 844);

/// Pump a widget inside the real Block Party theme with providers.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  Size size = goldenSurfaceSize,
  AuthService? authOverride,
  MembershipProvider? membershipOverride,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final auth = authOverride ?? AuthService.mock();
  final membership = membershipOverride ?? MembershipProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
        ChangeNotifierProvider.value(value: membership),
        ChangeNotifierProvider(
          create: (_) => SavedProvider(authService: auth),
        ),
        ChangeNotifierProvider(
          create: (_) => SuggestionProvider(authService: auth),
        ),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
