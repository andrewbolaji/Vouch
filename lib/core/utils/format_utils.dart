/// Shared formatting utilities.
///
/// Extracted from vote_button.dart and restaurant_card.dart
/// to eliminate duplication.
String formatCount(int count) {
  if (count >= 1000000) {
    final value = count / 1000000;
    return value == value.roundToDouble()
        ? '${value.round()}M'
        : '${value.toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    final value = count / 1000;
    return value == value.roundToDouble()
        ? '${value.round()}k'
        : '${value.toStringAsFixed(1)}k';
  }
  return count.toString();
}

/// Human-readable relative timestamp.
///
/// Handles future dates gracefully (returns 'just now')
/// to avoid confusing display from device clock skew.
String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  // Future dates (clock skew) -- don't show negative
  if (diff.isNegative) return 'just now';

  if (diff.inDays > 365) {
    return '${diff.inDays ~/ 365}y ago';
  }
  if (diff.inDays > 30) {
    return '${diff.inDays ~/ 30}mo ago';
  }
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes}m ago';
  }
  return 'just now';
}
