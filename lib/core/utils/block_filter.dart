import 'package:vouch/models/comment.dart';

/// Filters comments by removing those from blocked users.
///
/// This is the single source of truth for block filtering.
/// Both the restaurant detail screen and tests call this function.
List<Comment> filterBlockedComments(
  List<Comment> comments,
  Set<String> blockedUserIds,
) {
  return comments
      .where((c) => !blockedUserIds.contains(c.userId))
      .toList();
}
