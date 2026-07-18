import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/firebase_options.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/report_repository.dart';
import 'package:vouch/repositories/suggestion_repository.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/splash_screen.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/services/revenue_cat_service.dart';
import 'package:vouch/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: monitor-only (enforcement is a separate console step).
  await FirebaseAppCheck.instance.activate(
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );

  // Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: discarded_futures, must be synchronous callback
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await RevenueCatService.configure();

  final authService = AuthService();
  final analyticsService = AnalyticsService();
  final membershipProvider = MembershipProvider(authService: authService);

  runApp(
    VouchApp(
      authService: authService,
      analyticsService: analyticsService,
      membershipProvider: membershipProvider,
    ),
  );
}

class VouchApp extends StatelessWidget {
  const VouchApp({
    required this.authService,
    required this.analyticsService,
    required this.membershipProvider,
    super.key,
  });

  final AuthService authService;
  final AnalyticsService analyticsService;
  final MembershipProvider membershipProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            membershipProvider: membershipProvider,
          ),
        ),
        ChangeNotifierProvider.value(value: membershipProvider),
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: analyticsService),
        ChangeNotifierProvider(
          create: (_) => SavedProvider(
            authService: authService,
            userRepository: UserRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SuggestionProvider(
            authService: authService,
            suggestionRepository: SuggestionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportProvider(
            authService: authService,
            reportRepository: ReportRepository(),
          ),
        ),
      ],
      child: MaterialApp(
        title: BrandConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        navigatorObservers: [analyticsService.navigatorObserver],
        home: const SplashScreen(),
      ),
    );
  }
}
