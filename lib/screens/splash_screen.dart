import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/screens/home_screen.dart';
import 'package:vouch/screens/onboarding_screen.dart';
import 'package:vouch/screens/verify_email_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    unawaited(_controller.forward());
    unawaited(_navigateAfterDelay());
  }

  Future<void> _navigateAfterDelay() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;

    // Wait for the splash animation to finish
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Gate: unverified email users go to the verify screen.
    final auth = context.read<AuthService>();
    final needsVerify =
        auth.currentUser?.needsEmailVerification ?? false;

    final Widget destination;
    if (needsVerify) {
      destination = const VerifyEmailScreen();
    } else if (hasSeenOnboarding) {
      destination = const HomeScreen();
    } else {
      destination = const OnboardingScreen();
    }

    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation1, animation2) =>
              destination,
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration:
              const Duration(milliseconds: 500),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.borderColor,
                      width: AppTheme.borderInkWidth,
                    ),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: AppTheme.onAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  BrandConfig.appName,
                  style: AppTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text.rich(
                  TextSpan(
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Where locals '),
                      TextSpan(
                        text: 'actually',
                        style: TextStyle(color: AppTheme.accent),
                      ),
                      const TextSpan(text: ' eat'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
