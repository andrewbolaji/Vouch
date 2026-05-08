import 'package:flutter/material.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/theme/app_theme.dart';

class LocationCard extends StatelessWidget {

  const LocationCard({required this.location, super.key});
  final RestaurantLocation location;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: IconTheme(
        data: IconThemeData(color: Theme.of(context).colorScheme.primary),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(location.address, style: AppTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
