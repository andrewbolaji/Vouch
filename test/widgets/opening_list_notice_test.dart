import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/widgets/opening_list_notice.dart';

/// The disclosure required by Fix B: while the curated baseline still
/// carries weight, the screen says so, and when it expires the line
/// goes away.
///
/// Both halves are asserted. A test that only proved the line appears
/// would pass just as happily against a widget that never hides it,
/// and a line that outlived the thumb it discloses would be a
/// different lie rather than the same truth.
void main() {
  Widget wrap(double weight) => MaterialApp(
        home: Scaffold(
          body: OpeningListNotice(baselineWeight: weight),
        ),
      );

  group('OpeningListNotice', () {
    testWidgets('says the list is opening while the weight is above zero',
        (tester) async {
      await tester.pumpWidget(wrap(1));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Opening list.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Ranked by locals as votes come in.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('still says it on the last vote before expiry',
        (tester) async {
      // The curve reaches zero exactly, so the interesting case is the
      // one just above it. A `>= 0` or a rounded check would drop the
      // line early, while the ranking was still holding the order.
      await tester.pumpWidget(wrap(0.001));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Opening list.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing at all once the weight reaches zero',
        (tester) async {
      await tester.pumpWidget(wrap(0));
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(
        find.textContaining('Opening list.', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('renders nothing if the weight somehow arrives negative',
        (tester) async {
      // baselineWeight is clamped at zero by the writer, so a negative
      // value means something upstream is broken. Rendering a notice
      // that reads as normal would hide that.
      await tester.pumpWidget(wrap(-1));
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
    });
  });
}
