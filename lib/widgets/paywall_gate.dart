import 'dart:async';
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
    this.isAwaitingConfirmation = false,
    this.onRetryConfirmation,
    this.confirmationExhausted = false,
  });
  final Widget child;
  final bool isLocked;
  final VoidCallback onUpgradeTap;
  final String message;
  final String source;

  /// True when the user has paid but the custom claim has not landed.
  ///
  /// Content stays locked, because firestore.rules gates on the claim
  /// and unlocking early would produce denied reads, but the pitch is
  /// replaced: someone who just paid must not be shown a sales
  /// message for the thing they already bought.
  final bool isAwaitingConfirmation;

  /// Re-checks the claim. Gives a paying user something to do other
  /// than wait.
  final Future<void> Function()? onRetryConfirmation;

  /// True once a retry has been tried and the claim still has not
  /// landed, which is when reassurance about the money matters.
  final bool confirmationExhausted;

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

  /// The pending state: paid, not yet unlocked.
  ///
  /// Wording is deliberately about the unlock, not about payment
  /// having failed, and does not raise doubts the user did not
  /// already have. The exhausted variant is the only one that
  /// mentions money, because that is the only point where someone
  /// starts wondering where it went.
  Widget _buildAwaitingConfirmation(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          widget.confirmationExhausted
              ? 'Still unlocking. Your purchase went through, so '
                  'nothing is lost. If this has not cleared in a few '
                  'minutes, contact support.'
              : 'Payment received. Unlocking your access now.',
          style: AppTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        if (widget.onRetryConfirmation != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          TextButton(
            onPressed: () => unawaited(widget.onRetryConfirmation!()),
            child: Text(
              'Check again',
              style: AppTheme.buttonText.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ],
    );
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
              color: AppTheme.inkScrim.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: widget.isAwaitingConfirmation
                    ? _buildAwaitingConfirmation(context)
                    : Column(
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
