import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vouch/core/utils/format_utils.dart';
import 'package:vouch/theme/app_theme.dart';

class VoteButton extends StatefulWidget {

  const VoteButton({
    required this.voteCount,
    required this.hasVoted,
    required this.onTap,
    super.key,
  });
  final int voteCount;
  final bool hasVoted;
  final VoidCallback onTap;

  @override
  State<VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<VoteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    unawaited(_controller.forward().then((_) => _controller.reverse()));
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final voted = widget.hasVoted;
    final color = voted ? AppTheme.accent : AppTheme.textSecondary;

    return Semantics(
      button: true,
      label: voted
          ? 'Remove vote, ${widget.voteCount} votes'
          : 'Vote, ${widget.voteCount} votes',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: voted
                ? AppTheme.accent.withValues(alpha: 0.15)
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: voted ? AppTheme.accent : AppTheme.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(Icons.arrow_upward_rounded, color: color, size: 18),
              ),
              const SizedBox(
                width: AppTheme.spacingXsSm,
              ),
              Text(
                formatCount(widget.voteCount),
                style: AppTheme.labelLarge.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
