import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vouch/config/demo_image_overrides.dart';
import 'package:vouch/models/restaurant.dart';
import 'package:vouch/theme/app_theme.dart';

/// A resolved image source: either a bundled asset or a network URL.
class ImageSource {
  const ImageSource.asset(this.assetPath) : networkUrl = null;
  const ImageSource.network(this.networkUrl) : assetPath = null;

  final String? assetPath;
  final String? networkUrl;

  bool get isAsset => assetPath != null;
}

/// Resolves and displays a restaurant's primary image.
///
/// If [kUseDemoImageOverrides] is true and the restaurant's name (lowercased,
/// trimmed) matches a key in [kDemoImageOverrides], loads the bundled asset.
/// Otherwise falls through to [Restaurant.imageUrl] via [CachedNetworkImage].
///
/// Use this widget for the card image (always primary only).
/// For the detail hero, use [resolveImageSources] to get all images
/// and feed them to the hero widget.
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

  /// Returns the primary demo asset path if overrides are enabled and the
  /// name matches, or null to fall through to the network image.
  static String? resolveDemoAsset(String restaurantName) {
    if (!kUseDemoImageOverrides) return null;
    return kDemoImageOverrides[restaurantName.toLowerCase().trim()]?.primary;
  }

  /// Returns 1 or 2 [ImageSource]s for a restaurant. The first is always
  /// the primary. A second is included only if a demo override provides one.
  /// This is the input for the detail hero widget.
  static List<ImageSource> resolveImageSources(Restaurant restaurant) {
    if (!kUseDemoImageOverrides) {
      return [ImageSource.network(restaurant.imageUrl)];
    }
    final paths =
        kDemoImageOverrides[restaurant.name.toLowerCase().trim()];
    if (paths == null) {
      return [ImageSource.network(restaurant.imageUrl)];
    }
    return [
      ImageSource.asset(paths.primary),
      if (paths.secondary != null) ImageSource.asset(paths.secondary),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final demoAsset = resolveDemoAsset(restaurant.name);

    if (demoAsset != null) {
      return Semantics(
        label: '${restaurant.name} photo',
        image: true,
        child: Image.asset(
          demoAsset,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stack) => _placeholder(),
        ),
      );
    }

    return Semantics(
      label: '${restaurant.name} photo',
      image: true,
      child: CachedNetworkImage(
        imageUrl: restaurant.imageUrl,
        width: width,
        height: height,
      fit: fit,
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _placeholderWithIcon(),
      ),
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

/// Builds a single image widget from an [ImageSource].
/// Shared by [RestaurantImage] and the detail hero widget.
Widget buildImageFromSource(
  ImageSource source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  double iconSize = 40,
}) {
  if (source.isAsset) {
    return Image.asset(
      source.assetPath!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceVariant,
        child: Icon(Icons.restaurant, color: AppTheme.textTertiary,
            size: iconSize),
      ),
    );
  }
  return CachedNetworkImage(
    imageUrl: source.networkUrl!,
    width: width,
    height: height,
    fit: fit,
    placeholder: (context, url) => Container(
      width: width,
      height: height,
      color: AppTheme.surfaceVariant,
    ),
    errorWidget: (context, url, error) => Container(
      width: width,
      height: height,
      color: AppTheme.surfaceVariant,
      child: Icon(Icons.restaurant, color: AppTheme.textTertiary,
          size: iconSize),
    ),
  );
}
