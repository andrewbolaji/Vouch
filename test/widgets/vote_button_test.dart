// VoteButton had no widget test at all until this file. The
// interaction suite drives it via find.byIcon, which exercises the
// happy-path tap but says nothing about the in-flight state, so the
// isVoting dimming and tap suppression shipped unproven. That is the
// same shape of gap as the composition-root one: behaviour that
// exists in the code and is never executed by a test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/widgets/vote_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  /// The opacity VoteButton applies to itself while a write is in
  /// flight. Read from the AnimatedOpacity the button wraps its own
  /// container in, not from an ancestor, so this cannot pass by
  /// picking up some unrelated opacity in the tree.
  double dimOpacity(WidgetTester tester) {
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(VoteButton),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    return opacity.opacity;
  }

  testWidgets('is fully opaque when not voting', (tester) async {
    await tester.pumpWidget(
      wrap(
        VoteButton(
          voteCount: 3,
          hasVoted: false,
          onTap: () {},
        ),
      ),
    );

    expect(dimOpacity(tester), 1.0);
  });

  testWidgets('dims while a vote write is in flight', (tester) async {
    await tester.pumpWidget(
      wrap(
        VoteButton(
          voteCount: 3,
          hasVoted: false,
          isVoting: true,
          onTap: () {},
        ),
      ),
    );

    expect(dimOpacity(tester), lessThan(1.0));
  });

  testWidgets('suppresses a tap while a write is in flight',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        VoteButton(
          voteCount: 3,
          hasVoted: false,
          isVoting: true,
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byType(VoteButton));
    await tester.pump();

    // A second tap mid-write would fire a second, overlapping
    // Firestore write against the same vote document.
    expect(taps, 0);
  });

  testWidgets('accepts a tap once the write has settled',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        VoteButton(
          voteCount: 3,
          hasVoted: false,
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byType(VoteButton));
    await tester.pump();

    // Proves the suppression above is conditional on isVoting, not
    // the button being inert in general.
    expect(taps, 1);
  });
}
