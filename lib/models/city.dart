class City {

  const City({
    required this.id,
    required this.name,
    required this.state,
    required this.imageUrl,
    required this.description,
    this.restaurantCount = 0,
  });
  final String id;
  final String name;
  final String state;
  final String imageUrl;
  final String description;
  final int restaurantCount;

  String get displayName => '$name, $state';
}
