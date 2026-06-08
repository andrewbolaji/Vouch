import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vouch/config/demo_image_overrides.dart';
import 'package:vouch/models/restaurant.dart';
import 'package:vouch/theme/app_theme.dart';

/// Resolves and displays a restaurant's image.
///
/// If [kUseDemoImageOverrides] is true and the restaurant's name (lowercased,
/// trimmed) matches a key in [kDemoImageOverrides], loads the bundled asset.
/// Otherwise falls through to [Restaurant.imageUrl] via [CachedNetworkImage].
///
/// Use this widget everywhere a restaurant image renders (card, detail hero)
/// so the demo override applies from one place.
class RestaurantImage extends StatelessWidget {
  const RestaurantImage({
    required this.restaurant,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
    super.key,
  });

  final Restaurant restaurant;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  /// Returns the demo asset path if overrides are enabled and the name
  /// matches, or null to fall through to the network image.
  static String? resolveDemoAsset(String restaurantName) {
    if (!kUseDemoImageOverrides) return null;
    return kDemoImageOverrides[restaurantName.toLowerCase().trim()];
  }

  @override
  Widget build(BuildContext context) {
    final demoAsset = resolveDemoAsset(restaurant.name);

    if (demoAsset != null) {
      return Image.asset(
        demoAsset,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stack) => _placeholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: restaurant.imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _placeholder(),
      errorWidget: (context, url, error) => _placeholderWithIcon(),
    );
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceVariant,
      );

  Widget _placeholderWithIcon() => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceVariant,
        child: Icon(
          Icons.restaurant,
          color: AppTheme.textTertiary,
          size: iconSize,
        ),
      );
}
