import 'dart:async';

import 'package:share_plus/share_plus.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/models/models.dart';

class ShareService {
  ShareService._();

  static void shareRestaurant(Restaurant restaurant) {
    final text =
        'Check out ${restaurant.name} '
        'on ${BrandConfig.appName}. '
        'Ranked #${restaurant.rank} in the city. '
        '${BrandConfig.shareUrl}';
    unawaited(Share.share(text));
  }

  static void shareCity(City city) {
    final text =
        'See the Top 10 restaurants in '
        '${city.displayName} on '
        '${BrandConfig.appName}. '
        '${BrandConfig.shareUrl}';
    unawaited(Share.share(text));
  }

  static void shareApp() {
    const text =
        '${BrandConfig.appName} - '
        '${BrandConfig.tagline}. '
        '${BrandConfig.shareUrl}';
    unawaited(Share.share(text));
  }
}
