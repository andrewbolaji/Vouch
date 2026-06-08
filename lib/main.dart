import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/firebase_options.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/suggestion_repository.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/splash_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService();
  runApp(VouchApp(authService: authService));
}

class VouchApp extends StatelessWidget {
  const VouchApp({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => MembershipProvider()),
        ChangeNotifierProvider.value(value: authService),
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
      ],
      child: MaterialApp(
        title: BrandConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: const SplashScreen(),
      ),
    );
  }
}
