import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class SaveButton extends StatefulWidget {

  const SaveButton({required this.isSaved, required this.onTap, super.key});
  final bool isSaved;
  final VoidCallback onTap;

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isSaved) {
      unawaited(_controller.forward().then((_) => _controller.reverse()));
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isSaved ? 'Remove from saved' : 'Save restaurant',
      child: GestureDetector(
        onTap: _handleTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: widget.isSaved
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
