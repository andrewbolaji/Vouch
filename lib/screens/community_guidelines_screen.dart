import 'package:flutter/material.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/theme/app_theme.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Community guidelines', style: AppTheme.headlineLarge),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          Text(
            'Vouch is for talking about food. Keep it about the food.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Do not post', style: AppTheme.labelLarge),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Hate speech or slurs, harassment or threats, sexual content, '
            'spam or advertising, or anything you know to be false about a '
            'restaurant.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Reporting', style: AppTheme.labelLarge),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Every comment has a report option, and every user can be '
            'blocked from your view. We read every report and remove '
            'anything that breaks these rules.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Questions or appeals', style: AppTheme.labelLarge),
          const SizedBox(height: AppTheme.spacingXs),
          Text(BrandConfig.supportEmail, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}
