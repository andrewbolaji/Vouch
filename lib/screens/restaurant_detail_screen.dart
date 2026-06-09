import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vouch/core/utils/block_filter.dart';
import 'package:vouch/models/comment.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/sign_in_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/services/share_service.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/comment_tile.dart';
import 'package:vouch/widgets/report_comment_sheet.dart';
import 'package:vouch/widgets/insider_notes.dart';
import 'package:vouch/widgets/location_card.dart';
import 'package:vouch/widgets/paywall_gate.dart';
import 'package:vouch/widgets/rating_pill.dart';
import 'package:vouch/widgets/save_button.dart';
import 'package:vouch/widgets/restaurant_detail_hero.dart';
import 'package:vouch/widgets/restaurant_image.dart';
import 'package:vouch/widgets/vote_button.dart';

class RestaurantDetailScreen extends StatefulWidget {

  const RestaurantDetailScreen({required this.restaurantId, super.key});
  final String restaurantId;

  @override
  State<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _commentController = TextEditingController();
  String? _replyingToId;
  String? _replyingToUserName;
  Set<String> _blockedUserIds = {};

  UserRepository get _userRepo {
    try {
      return context.read<UserRepository>();
    } on ProviderNotFoundException catch (_) {
      return UserRepository();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadBlockedUsers());
  }

  Future<void> _loadBlockedUsers() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final ids = await _userRepo.getBlockedIds(uid);
      if (mounted) setState(() => _blockedUserIds = ids.toSet());
    } on Exception catch (_) {
      // Best effort; empty blocklist is safe default.
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final membership = context.watch<MembershipProvider>();
    final savedProvider = context.watch<SavedProvider>();
    final auth = context.watch<AuthService>();
    final restaurant = appState.restaurantById(widget.restaurantId);

    if (restaurant == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background),
        body: Center(
          child: Text(
            'Restaurant not found',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final currentUid = auth.currentUser?.uid;
    final allComments = appState.commentsForRestaurant(widget.restaurantId);
    final comments = filterBlockedComments(allComments, _blockedUserIds);
    final hasVoted = appState.hasVoted(widget.restaurantId);
    final isSaved = savedProvider.isSaved(widget.restaurantId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.background,
            foregroundColor: AppTheme.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: RestaurantDetailHero(
                images: RestaurantImage.resolveImageSources(restaurant),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share restaurant',
                onPressed: () => ShareService.shareRestaurant(restaurant),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RatingPill(rank: restaurant.rank, isLarge: true),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: AppTheme.displayMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingXs),
                            Text(
                              '${restaurant.cuisine}'
                              '  ${restaurant.priceLevelDisplay}',
                              style: AppTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Vibe tags
                  if (restaurant.vibeTags.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: restaurant.vibeTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSm +
                                AppTheme.spacingXxs,
                            vertical: AppTheme.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentMuted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXl,
                            ),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.accent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingMd),
                  // Action row
                  Row(
                    children: [
                      VoteButton(
                        voteCount: restaurant.voteCount,
                        hasVoted: hasVoted,
                        onTap: () => appState.toggleVote(widget.restaurantId),
                      ),
                      const Spacer(),
                      if (!auth.isSignedIn)
                        Semantics(
                          button: true,
                          label: 'Sign in to save restaurants',
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SignInScreen(),
                              ),
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Icon(
                                  Icons.bookmark_border,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (membership.canSaveRestaurants)
                        SaveButton(
                          isSaved: isSaved,
                          onTap: () async {
                            final error = await savedProvider
                                .toggleSaved(widget.restaurantId);
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error.message),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          },
                        )
                      else
                        Semantics(
                          button: true,
                          label: 'Upgrade to save restaurants',
                          child: GestureDetector(
                            onTap: () {
                              unawaited(HapticFeedback.mediumImpact());
                              _showUpgrade(context);
                            },
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Icon(
                                  Icons.bookmark_border,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Description
                  Text(restaurant.description, style: AppTheme.bodyLarge),
                  // Locations
                  if (restaurant.locations.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingLg),
                    Text('Locations', style: AppTheme.headlineMedium),
                    const SizedBox(height: AppTheme.spacingSm),
                    ...restaurant.locations.map(
                      (loc) => LocationCard(location: loc),
                    ),
                  ],
                  // Insider notes
                  if (restaurant.whatToOrder != null ||
                      restaurant.insiderTip != null) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    if (membership.canViewInsiderTips)
                      InsiderNotes(
                        whatToOrder: restaurant.whatToOrder,
                        tip: restaurant.insiderTip,
                      )
                    else
                      PaywallGate(
                        isLocked: true,
                        onUpgradeTap: () {
                          unawaited(
                            HapticFeedback.mediumImpact(),
                          );
                          _showUpgrade(context);
                        },
                        message: 'City Insider exclusive',
                        child: const InsiderNotes(
                          whatToOrder: 'Unlock to see what '
                              'insiders order here',
                          tip: 'Unlock to see the '
                              'insider tip',
                        ),
                      ),
                  ],
                  // Comments
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Comments', style: AppTheme.headlineMedium),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Reply indicator
                  if (_replyingToId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingSm,
                      ),
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, color: AppTheme.accent, size: 16),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              'Replying to $_replyingToUserName',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Cancel reply',
                            child: GestureDetector(
                              onTap: _cancelReply,
                              child: Icon(
                                Icons.close,
                                color: AppTheme.textTertiary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Comment input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          maxLength: 500,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: _replyingToId != null
                                ? 'Write a reply...'
                                : 'Add a comment...',
                            hintStyle: AppTheme.bodyMedium,
                            filled: true,
                            fillColor: AppTheme.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                              vertical: AppTheme.spacingSm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      IconButton(
                        onPressed: _submitComment,
                        tooltip: _replyingToId != null
                            ? 'Send reply'
                            : 'Send comment',
                        icon: Icon(Icons.send, color: AppTheme.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  if (comments.isEmpty)
                    Text(
                      'No comments yet. Be the first.',
                      style: AppTheme.bodyMedium,
                    )
                  else
                    ...comments.map((comment) {
                      final replies = filterBlockedComments(
                        appState.repliesForComment(comment.id),
                        _blockedUserIds,
                      );
                      final isOwn = currentUid == comment.userId;
                      return CommentTile(
                        comment: comment,
                        replies: replies,
                        isOwnComment: isOwn,
                        onReply: (parentId) =>
                            _startReply(parentId, comment.userName),
                        onReport: () => _reportComment(comment),
                        onBlock: () => _blockUser(comment.userId),
                      );
                    }),
                  const SizedBox(height: AppTheme.spacingXl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startReply(String parentId, String userName) {
    setState(() {
      _replyingToId = parentId;
      _replyingToUserName = userName;
    });
    _commentController.clear();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToUserName = null;
    });
  }

  void _submitComment() {
    if (_commentController.text.trim().isEmpty) return;
    final appState = context.read<AppState>();
    final membership = context.read<MembershipProvider>();
    appState.addComment(
      restaurantId: widget.restaurantId,
      text: _commentController.text.trim(),
      parentId: _replyingToId,
      isInsider: membership.hasInsiderBadge,
    );
    _commentController.clear();
    _cancelReply();
  }

  Future<void> _reportComment(Comment comment) async {
    final reason = await ReportCommentSheet.show(context);
    if (reason == null || !mounted) return;

    final reportProvider = context.read<ReportProvider>();
    final restaurant = context.read<AppState>().restaurantById(
      widget.restaurantId,
    );
    try {
      await reportProvider.submitReport(
        commentId: comment.id,
        commentPath:
            'restaurants/${widget.restaurantId}/comments/${comment.id}',
        restaurantId: widget.restaurantId,
        cityId: restaurant?.cityId ?? '',
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you.'),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(String blockedUid) async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _userRepo.addBlock(uid, blockedUid);
      if (mounted) {
        setState(() => _blockedUserIds = {..._blockedUserIds, blockedUid});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showUpgrade(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const UpgradeScreen(),
      ),
    );
  }
}
