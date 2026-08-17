import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

/// Tells the user, while it is true, that the list is still opening.
///
/// A city launches with a curated order, and for a while the ranking
/// keeps a thumb on it so that a handful of votes cannot reorder an
/// editorial Top 10 overnight. That thumb decays to exactly zero at a
/// stated number of votes, after which rank is votes and nothing else.
///
/// This line is the difference between that thumb and a lie. It is a
/// requirement of Fix B rather than polish: nobody knows yet whether
/// the decay takes three weeks or three months, since production has
/// never held a vote, and an undisclosed thumb on the scale for an
/// unknown number of months is not something the app gets to do
/// quietly.
///
/// Renders nothing once the weight reaches zero. The absence is the
/// signal, and it means "ranked by locals" has become the whole truth.
///
/// See docs/FIX_B_DESIGN.md, "While the baseline is above zero, the
/// city screen says so".
class OpeningListNotice extends StatelessWidget {
  const OpeningListNotice({required this.baselineWeight, super.key});

  /// Read from the city document, never recomputed here. One writer
  /// (recomputeAllRanks), one number, read-only everywhere else.
  final double baselineWeight;

  @override
  Widget build(BuildContext context) {
    if (baselineWeight <= 0) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule,
          size: 13,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: AppTheme.spacingXs),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Opening list.',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: ' Ranked by locals as votes come in.',
                ),
              ],
            ),
            style: AppTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
