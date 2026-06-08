// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared warm-dark neutrals (same across all three accents).
class _N {
  static const background = Color(0xFF0F0D0B);
  static const surface = Color(0xFF1A1714);
  static const surfaceVariant = Color(0xFF252118);
  static const textPrimary = Color(0xFFF5F0EB);
  static const textSecondary = Color(0xFFB8AFA6);
  static const textTertiary = Color(0xFF7A7269);
  static const divider = Color(0xFF2E2A27);
  static const primaryMuted = Color(0xFF3D3530);
}

/// Accent candidate with its muted companion.
class _Accent {
  const _Accent(this.color, this.muted, this.label);
  final Color color;
  final Color muted;
  final String label;
}

const _accents = [
  _Accent(Color(0xFFFF3B5C), Color(0xFFCC2F4A), 'pink_FF3B5C'),
  _Accent(Color(0xFFFF5436), Color(0xFFCC432B), 'vermilion_FF5436'),
  _Accent(Color(0xFFE03E52), Color(0xFFB33242), 'pomegranate_E03E52'),
];

TextStyle _serif(double size, {FontWeight weight = FontWeight.w400, Color color = _N.textPrimary}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'RobotoSerif', fontFamilyFallback: const ['Roboto']);

TextStyle _sans(double size, {FontWeight weight = FontWeight.w400, Color color = _N.textPrimary}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color);

void main() {
  for (final a in _accents) {
    testWidgets('Mockup: Home screen — ${a.label}', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: _N.background),
          home: Scaffold(
            backgroundColor: _N.background,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vouch', style: _serif(24)),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    style: _sans(12, color: _N.textPrimary),
                                    children: [
                                      const TextSpan(text: 'Where locals '),
                                      TextSpan(text: 'actually', style: _serif(14, color: a.color).copyWith(fontStyle: FontStyle.italic)),
                                      const TextSpan(text: ' eat'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: _N.surfaceVariant,
                              child: const Icon(Icons.person_outline, color: _N.textSecondary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _N.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: _N.textTertiary, size: 20),
                            const SizedBox(width: 8),
                            Text('Search cities...', style: _sans(14, color: _N.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // City grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                        children: [
                          _MockCityCard(name: 'Houston', state: 'TX', desc: 'The most diverse food city in America. No debate.', imgColor: const Color(0xFF8B4513)),
                          _MockCityCard(name: 'New York', state: 'NY', desc: 'If you can eat here, you can eat anywhere.', imgColor: const Color(0xFF2F4F4F)),
                          _MockCityCard(name: 'Los Angeles', state: 'CA', desc: 'Tacos, sushi, and everything between.', imgColor: const Color(0xFF4169E1)),
                          _MockCityCard(name: 'Chicago', state: 'IL', desc: 'Deep dish is just the beginning.', imgColor: const Color(0xFF8B0000)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Rank badges row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(8)),
                            child: Text('#1', style: _serif(18, color: _N.background)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: _N.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                            child: Text('#4', style: _serif(18)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: a.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: a.color),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward_rounded, color: a.color, size: 16),
                                const SizedBox(width: 4),
                                Text('2.8k', style: _sans(13, weight: FontWeight.w600, color: a.color)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Vibe tags
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Worth the Wait', 'Big Portions', 'Loud and Fun'].map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: a.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: a.color.withValues(alpha: 0.3)),
                            ),
                            child: Text(tag, style: _sans(12, color: a.color)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Insider notes preview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_N.primaryMuted, _N.surfaceVariant],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: a.color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: a.color, size: 18),
                            const SizedBox(width: 8),
                            Text('Insider Notes', style: _serif(15, color: a.color).copyWith(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // CTA button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: a.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text('Start 7-day free trial', style: _sans(14, weight: FontWeight.w600, color: _N.background)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Accent label
                    Center(child: Text(a.label.replaceAll('_', ' ').toUpperCase(), style: _sans(10, weight: FontWeight.w500, color: _N.textTertiary))),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/home_${a.label}.png'),
      );
    });
  }
}

class _MockCityCard extends StatelessWidget {
  const _MockCityCard({
    required this.name,
    required this.state,
    required this.desc,
    required this.imgColor,
  });

  final String name;
  final String state;
  final String desc;
  final Color imgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _N.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [imgColor, imgColor.withValues(alpha: 0.6)],
                ),
              ),
              child: Center(
                child: Icon(Icons.location_city, color: _N.textTertiary.withValues(alpha: 0.5), size: 32),
              ),
            ),
          ),
          Container(
            color: _N.surface,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name, $state', style: _serif(14, color: _N.textPrimary)),
                const SizedBox(height: 2),
                Text(desc, style: _sans(11, color: _N.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
