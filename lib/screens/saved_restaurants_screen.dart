import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/restaurant_card.dart';

class SavedRestaurantsScreen extends StatelessWidget {
  const SavedRestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final savedProvider = context.watch<SavedProvider>();

    final savedRestaurants = appState.restaurants
        .where((r) => savedProvider.isSaved(r.id))
        .toList();

    // Group by city with proper typing
    final grouped = <String, List<Restaurant>>{};
    for (final r in savedRestaurants) {
      final city = appState.cityById(r.cityId);
      final cityName = city?.displayName ?? r.cityId;
      grouped.putIfAbsent(cityName, () => []).add(r);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Saved', style: AppTheme.headlineLarge),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: savedRestaurants.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    color: AppTheme.textTertiary,
                    size: 48,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No saved restaurants yet',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    'Save your favorites and they will appear here',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppTheme.spacingSm,
                        top: AppTheme.spacingSm,
                      ),
                      child: Text(entry.key, style: AppTheme.headlineMedium),
                    ),
                    ...entry.value.map(
                      (r) => RestaurantCard(
                        restaurant: r,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RestaurantDetailScreen(restaurantId: r.id),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
