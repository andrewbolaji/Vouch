import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vouch/services/notification_service.dart';
import 'package:vouch/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _rankingAlerts = true;
  bool _newCityAlerts = true;
  bool _weeklyDigest = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final ranking = await NotificationService.getRankingAlerts();
    final newCity = await NotificationService.getNewCityAlerts();
    final digest = await NotificationService.getWeeklyDigest();
    if (mounted) {
      setState(() {
        _rankingAlerts = ranking;
        _newCityAlerts = newCity;
        _weeklyDigest = digest;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Notifications', style: AppTheme.headlineLarge),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                Text(
                  'Choose which notifications you receive.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                _NotificationToggle(
                  title: 'Ranking changes',
                  subtitle:
                      'Get notified when a restaurant you voted'
                      ' for moves up or down.',
                  value: _rankingAlerts,
                  onChanged: (val) {
                    setState(() => _rankingAlerts = val);
                    unawaited(
                      NotificationService.setRankingAlerts(value: val),
                    );
                  },
                ),
                _NotificationToggle(
                  title: 'New cities',
                  subtitle: 'Be the first to know when a new city launches.',
                  value: _newCityAlerts,
                  onChanged: (val) {
                    setState(() => _newCityAlerts = val);
                    unawaited(
                      NotificationService.setNewCityAlerts(value: val),
                    );
                  },
                ),
                _NotificationToggle(
                  title: 'Weekly digest',
                  subtitle:
                      'A weekly summary of ranking changes'
                      ' across your saved cities.',
                  value: _weeklyDigest,
                  onChanged: (val) {
                    setState(() => _weeklyDigest = val);
                    unawaited(
                      NotificationService.setWeeklyDigest(value: val),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {

  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingXs),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Semantics(
            toggled: value,
            label: title,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
