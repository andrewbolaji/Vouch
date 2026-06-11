import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/screens/blocked_users_screen.dart';
import 'package:vouch/screens/notification_settings_screen.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';
import 'package:vouch/screens/sign_in_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/services/share_service.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/premium_badge.dart';
import 'package:vouch/widgets/suggestion_box.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final membership = context.watch<MembershipProvider>();
    final savedProvider = context.watch<SavedProvider>();
    final auth = context.watch<AuthService>();
    final validIds =
        appState.restaurants.map((r) => r.id).toSet();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Profile', style: AppTheme.headlineLarge),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.surfaceVariant,
                    child: Icon(
                      Icons.person,
                      color: AppTheme.textSecondary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.displayName, style: AppTheme.headlineMedium),
                        const SizedBox(height: AppTheme.spacingXs),
                        PremiumBadge(label: membership.tierName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            // Menu items
            if (!auth.isSignedIn)
              _ProfileMenuItem(
                icon: Icons.login,
                label: 'Sign In',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SignInScreen(),
                  ),
                ),
              ),
            _ProfileMenuItem(
              icon: Icons.bookmark_outline,
              label: 'Saved Restaurants',
              trailing: '${savedProvider.savedCountFor(validIds)}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedRestaurantsScreen(),
                ),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.star_outline,
              label: 'Upgrade Plan',
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const UpgradeScreen(),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.block,
              label: 'Blocked Users',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BlockedUsersScreen(),
                ),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
            const _ProfileMenuItem(
              icon: Icons.share_outlined,
              label: 'Share App',
              onTap: ShareService.shareApp,
            ),
            _ProfileMenuItem(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => _showAboutDialog(context),
            ),
            if (kDebugMode)
              _ProfileMenuItem(
                icon: Icons.bug_report,
                label: 'Test Crash (debug only)',
                onTap: () =>
                    FirebaseCrashlytics.instance.crash(),
              ),
            if (auth.isSignedIn) ...[
              _ProfileMenuItem(
                icon: Icons.logout,
                label: 'Sign Out',
                onTap: () {
                  unawaited(auth.signOut());
                },
              ),
              _ProfileMenuItem(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            // Suggestion box
            const SuggestionBox(),
            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text('Delete account?', style: AppTheme.headlineLarge),
        content: Text(
          'This will permanently delete your account and all your data. '
          'This cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _executeAccountDeletion(context);
            },
            child: Text(
              'Delete',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  /// Attempts deletion. On requires-recent-login, prompts re-auth
  /// and retries exactly once.
  static Future<void> _executeAccountDeletion(BuildContext context) async {
    final auth = context.read<AuthService>();
    try {
      final uid = await auth.deleteAccount();
      await _clearLocalUserData(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deleted.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } on AuthException catch (e) {
      if (e.kind == AuthErrorKind.requiresRecentLogin && context.mounted) {
        await _showReauthDialog(context);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Shows a re-auth dialog, then retries deletion exactly once.
  static Future<void> _showReauthDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final method = auth.currentAuthMethod;

    if (method == AuthMethod.email) {
      await _showPasswordReauthDialog(context);
    } else if (method == AuthMethod.google || method == AuthMethod.apple) {
      await _showProviderReauthDialog(context, method!);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please sign out, sign back in, and try again.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  static Future<void> _showPasswordReauthDialog(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text(
          'Confirm your password',
          style: AppTheme.headlineLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'For security, enter your password to delete your account.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: AppTheme.bodyMedium,
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Confirm and delete',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final password = controller.text;

    final auth = context.read<AuthService>();
    try {
      await auth.reauthenticateWithPassword(password);
      final uid = await auth.deleteAccount();
      await _clearLocalUserData(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deleted.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  static Future<void> _showProviderReauthDialog(
    BuildContext context,
    AuthMethod method,
  ) async {
    final providerName = method == AuthMethod.google ? 'Google' : 'Apple';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text(
          'Sign in again to delete',
          style: AppTheme.headlineLarge,
        ),
        content: Text(
          'For security, sign in with $providerName again '
          'to confirm account deletion.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sign in with $providerName',
              style: AppTheme.buttonText.copyWith(
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthService>();
    try {
      await auth.reauthenticateWithProvider();
      final uid = await auth.deleteAccount();
      await _clearLocalUserData(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deleted.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Clears uid-scoped SharedPreferences keys after account deletion.
  static Future<void> _clearLocalUserData(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_restaurant_ids_$uid');
      await prefs.remove('suggestion_remaining_$uid');
      await prefs.remove('voted_restaurant_ids');
      await prefs.remove('notifications_ranking_alerts');
      await prefs.remove('notifications_new_cities');
      await prefs.remove('notifications_weekly_digest');
    } on Exception catch (_) {
      // Best effort; failing to clear local prefs is not fatal.
    }
  }

  static void _showAboutDialog(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text(BrandConfig.appName, style: AppTheme.displayMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: AppTheme.accentItalic.copyWith(
                  color: AppTheme.textPrimary,
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
            const SizedBox(height: AppTheme.spacingMd),
            Text(BrandConfig.description, style: AppTheme.bodyMedium),
            const SizedBox(height: AppTheme.spacingLg),
            Text('Version 1.0.0', style: AppTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingSm),
            Text(BrandConfig.supportEmail, style: AppTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: AppTheme.buttonText.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    ));
  }
}

class _ProfileMenuItem extends StatelessWidget {

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap, this.trailing,
  });
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingMd,
          ),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(child: Text(label, style: AppTheme.bodyLarge)),
              if (trailing != null) Text(trailing!, style: AppTheme.bodySmall),
              const SizedBox(width: AppTheme.spacingSm),
              Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
