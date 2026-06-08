import 'package:flutter/material.dart';
import 'package:vouch/core/utils/format_utils.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/premium_badge.dart';

class CommentTile extends StatelessWidget {

  const CommentTile({
    required this.comment, super.key,
    this.replies = const [],
    this.onReply,
  });
  final Comment comment;
  final List<Comment> replies;
  final ValueChanged<String>? onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.surfaceVariant,
                child: Text(
                  comment.userName[0].toUpperCase(),
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(comment.userName, style: AppTheme.labelMedium),
              if (comment.isInsider) ...[
                const SizedBox(width: AppTheme.spacingXsSm),
                const PremiumBadge(label: 'Insider'),
              ],
              const Spacer(),
              Text(timeAgo(comment.createdAt), style: AppTheme.bodySmall),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: AppTheme.spacingXs),
            child: Text(comment.text, style: AppTheme.bodyMedium),
          ),
          if (onReply != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 36,
                top: AppTheme.spacingXs,
              ),
              child: Semantics(
                button: true,
                label: 'Reply to ${comment.userName}',
                child: GestureDetector(
                  onTap: () => onReply?.call(comment.id),
                  child: Text(
                    'Reply',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.accent),
                  ),
                ),
              ),
            ),
          // Threaded replies
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: AppTheme.spacingSm),
              child: Column(
                children: replies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 2,
                          height: 40,
                          color: AppTheme.divider,
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    reply.userName,
                                    style: AppTheme.labelMedium,
                                  ),
                                  if (reply.isInsider) ...[
                                    const SizedBox(width: AppTheme.spacingXsSm),
                                    const PremiumBadge(label: 'Insider'),
                                  ],
                                ],
                              ),
                              Text(reply.text, style: AppTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
