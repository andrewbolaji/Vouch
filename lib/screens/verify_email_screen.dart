import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/screens/home_screen.dart';
import 'package:vouch/screens/sign_in_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

/// Shown after email/password sign-up or sign-in when
/// the user's email is not yet verified.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _message;
  bool _isChecking = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_resendCooldown <= 1) {
          _cooldownTimer?.cancel();
          if (mounted) setState(() => _resendCooldown = 0);
        } else {
          if (mounted) {
            setState(() => _resendCooldown--);
          }
        }
      },
    );
  }

  Future<void> _resendEmail() async {
    final auth = context.read<AuthService>();
    try {
      await auth.sendVerificationEmail();
      _startCooldown();
      if (mounted) {
        setState(() => _message = 'Verification email sent.');
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    final auth = context.read<AuthService>();
    try {
      final verified = await auth.reloadAndCheckVerified();
      if (!mounted) return;
      if (verified) {
        await auth.forceTokenRefresh();
        if (mounted) _navigateIn();
      } else {
        setState(() {
          _message = 'Not verified yet. Check your email and try again.';
        });
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _message = e.message);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// After verification, return to where the user came from.
  /// If there is a route below (sign-in pushed from restaurant detail),
  /// pop back to it. If this is the root (splash cold start), push home.
  void _navigateIn() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthService>();
    await auth.signOut();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: AppTheme.accent,
              size: 56,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text('Check your inbox', style: AppTheme.displayMedium),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'We sent a verification link to $email. '
              'Tap the link in the email, then come back '
              'here and tap Continue.',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Not seeing it? Check your spam or promotions folder.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingXl),
            // Continue button
            ElevatedButton(
              onPressed: _isChecking ? null : _checkVerified,
              style: AppTheme.accentButtonStyle,
              child: _isChecking
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.onAccent,
                        ),
                      ),
                    )
                  : Text(
                      'Continue',
                      style: AppTheme.buttonText.copyWith(
                        color: AppTheme.onAccent,
                      ),
                    ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            // Resend button
            Center(
              child: TextButton(
                onPressed: _resendCooldown > 0 ? null : _resendEmail,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend in ${_resendCooldown}s'
                      : 'Resend verification email',
                  style: AppTheme.bodyMedium.copyWith(
                    color: _resendCooldown > 0
                        ? AppTheme.textTertiary
                        : AppTheme.accent,
                  ),
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                _message!,
                style: AppTheme.bodySmall.copyWith(
                  color: _message == 'Verification email sent.'
                      ? AppTheme.accent
                      : AppTheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            // Sign out option
            Center(
              child: TextButton(
                onPressed: _signOut,
                child: Text(
                  'Use a different account',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
