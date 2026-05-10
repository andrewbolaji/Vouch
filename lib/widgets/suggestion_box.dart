import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/theme/app_theme.dart';

class SuggestionBox extends StatefulWidget {
  const SuggestionBox({super.key});

  @override
  State<SuggestionBox> createState() => _SuggestionBoxState();
}

class _SuggestionBoxState extends State<SuggestionBox> {
  final _textController = TextEditingController();
  SuggestionType _selectedType = SuggestionType.general;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestionProvider>();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggestion Box', style: AppTheme.headlineMedium),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            '${provider.remainingToday} of '
            '$kDailySuggestionCap suggestion remaining today',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Type selector
          Wrap(
            spacing: AppTheme.spacingSm,
            children: SuggestionType.values.map((type) {
              final isSelected = type == _selectedType;
              return ChoiceChip(
                label: Text(_typeLabel(type)),
                selected: isSelected,
                selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                backgroundColor: AppTheme.surfaceVariant,
                labelStyle: AppTheme.bodySmall.copyWith(
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.accent : AppTheme.divider,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedType = type);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Text field
          TextField(
            controller: _textController,
            maxLines: 3,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Share your suggestion...',
              hintStyle: AppTheme.bodyMedium,
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.canSubmitToday ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.onAccent,
                disabledBackgroundColor: AppTheme.surfaceVariant,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text('Submit', style: AppTheme.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_textController.text.trim().isEmpty) return;

    final provider = context.read<SuggestionProvider>();
    final success = provider.submitSuggestion(
      type: _selectedType,
      text: _textController.text.trim(),
    );

    if (success) {
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Suggestion submitted.'),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }

  String _typeLabel(SuggestionType type) {
    switch (type) {
      case SuggestionType.newRestaurant:
        return 'New Restaurant';
      case SuggestionType.correction:
        return 'Correction';
      case SuggestionType.newCity:
        return 'New City';
      case SuggestionType.general:
        return 'General';
    }
  }
}
