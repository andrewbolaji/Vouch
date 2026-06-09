import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          'This will permanently delete your account. '
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
              final auth = context.read<AuthService>();
              try {
                await auth.deleteAccount();
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
