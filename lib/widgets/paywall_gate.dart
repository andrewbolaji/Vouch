import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class PaywallGate extends StatelessWidget {

  const PaywallGate({
    required this.child,
    required this.isLocked,
    required this.onUpgradeTap,
    super.key,
    this.message = 'Upgrade to unlock',
  });
  final Widget child;
  final bool isLocked;
  final VoidCallback onUpgradeTap;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 32),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(message, style: AppTheme.labelLarge),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextButton(
                      onPressed: onUpgradeTap,
                      child: Text(
                        'See plans',
                        style: AppTheme.buttonText.copyWith(
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
