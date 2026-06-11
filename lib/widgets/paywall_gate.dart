import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/theme/app_theme.dart';

class PaywallGate extends StatefulWidget {

  const PaywallGate({
    required this.child,
    required this.isLocked,
    required this.onUpgradeTap,
    super.key,
    this.message = 'Upgrade to unlock',
    this.source = 'unknown',
  });
  final Widget child;
  final bool isLocked;
  final VoidCallback onUpgradeTap;
  final String message;
  final String source;

  @override
  State<PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends State<PaywallGate> {
  bool _logged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isLocked && !_logged) {
      _logged = true;
      context.read<AnalyticsService>().logPaywallView(
        source: widget.source,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocked) return widget.child;

    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: widget.child,
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
                    Text(widget.message, style: AppTheme.labelLarge),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextButton(
                      onPressed: widget.onUpgradeTap,
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
