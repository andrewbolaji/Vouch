class RestaurantLocation {

  const RestaurantLocation({
    required this.name,
    required this.address,
    this.latitude = 0,
    this.longitude = 0,
  });
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

class Restaurant {

  const Restaurant({
    required this.id,
    required this.cityId,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
    required this.description,
    required this.rank,
    this.voteCount = 0,
    this.priceLevel = 2,
    this.locations = const [],
    this.insiderTip,
    this.whatToOrder,
    this.vibeTags = const [],
  });
  final String id;
  final String cityId;
  final String name;
  final String cuisine;
  final String imageUrl;
  final String description;
  final int rank;
  final int voteCount;
  final double priceLevel;
  final List<RestaurantLocation> locations;
  final String? insiderTip;
  final String? whatToOrder;
  final List<String> vibeTags;

  String get priceLevelDisplay => r'$' * priceLevel.round();

  Restaurant copyWith({int? voteCount, int? rank}) {
    return Restaurant(
      id: id,
      cityId: cityId,
      name: name,
      cuisine: cuisine,
      imageUrl: imageUrl,
      description: description,
      rank: rank ?? this.rank,
      voteCount: voteCount ?? this.voteCount,
      priceLevel: priceLevel,
      locations: locations,
      insiderTip: insiderTip,
      whatToOrder: whatToOrder,
      vibeTags: vibeTags,
    );
  }
}
