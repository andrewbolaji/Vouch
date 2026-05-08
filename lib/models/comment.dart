class Comment {

  const Comment({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.isInsider = false,
  });
  final String id;
  final String restaurantId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;
  final String? parentId;
  final bool isInsider;
}
