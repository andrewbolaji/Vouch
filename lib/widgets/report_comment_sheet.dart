import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vouch/models/report.dart';
import 'package:vouch/screens/community_guidelines_screen.dart';
import 'package:vouch/theme/app_theme.dart';

/// Bottom sheet for reporting a comment.
///
/// Returns the selected [ReportReason], or null if the user dismisses.
class ReportCommentSheet extends StatelessWidget {
  const ReportCommentSheet({super.key});

  static Future<ReportReason?> show(BuildContext context) {
    return showModalBottomSheet<ReportReason>(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusMd),
        ),
      ),
      builder: (_) => const ReportCommentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: Text(
                'Why are you reporting this comment?',
                style: AppTheme.labelLarge,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            const _ReasonTile(
              reason: ReportReason.spam,
              label: 'Spam or advertising',
            ),
            const _ReasonTile(
              reason: ReportReason.harassment,
              label: 'Harassment or bullying',
            ),
            const _ReasonTile(
              reason: ReportReason.inappropriate,
              label: 'Inappropriate content',
            ),
            const _ReasonTile(
              reason: ReportReason.other,
              label: 'Something else',
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: GestureDetector(
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  unawaited(
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CommunityGuidelinesScreen(),
                      ),
                    ),
                  );
                },
                child: Text(
                  'What we remove',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    decoration: TextDecoration.underline,
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

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.label});

  final ReportReason reason;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: AppTheme.bodyMedium),
      onTap: () => Navigator.of(context).pop(reason),
    );
  }
}
