import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/screens/home_screen.dart';
import 'package:vouch/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = [
    const _OnboardingPage(
      icon: Icons.emoji_food_beverage,
      title: 'Curated, not crowdsourced',
      subtitle:
          'Every city gets a Top 10, ranked by the'
          ' people who actually live there.',
    ),
    const _OnboardingPage(
      icon: Icons.how_to_vote,
      title: 'Your vote matters',
      subtitle:
          'Upvote your favorites. The rankings shift'
          ' based on real local opinions.',
    ),
    const _OnboardingPage(
      icon: Icons.star_border,
      title: 'Unlock insider access',
      subtitle:
          'Get the full Top 10, insider tips on what'
          ' to order, and save your favorites.',
    ),
  ];

  Future<void> _goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => unawaited(_goToHome()),
                child: Text(
                  'Skip',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, color: AppTheme.accent, size: 80),
                        const SizedBox(height: AppTheme.spacingXl),
                        Text(
                          page.title,
                          style: AppTheme.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          page.subtitle,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Indicators and button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXs,
                      ),
                        width: _currentPage == index ? 24 : 8,
                        height: AppTheme.spacingSm,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.accent
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppTheme.spacingXs,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          unawaited(
                            _pageController.nextPage(
                              duration: const Duration(
                                milliseconds: 300,
                              ),
                              curve: Curves.easeInOut,
                            ),
                          );
                        } else {
                          unawaited(_goToHome());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.onAccent,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: AppTheme.buttonText.copyWith(
                          color: AppTheme.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}
