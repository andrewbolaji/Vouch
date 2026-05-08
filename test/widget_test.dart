import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/main.dart';

void main() {
  testWidgets('App launches', (tester) async {
    await tester.pumpWidget(const VouchApp());
    expect(find.byType(VouchApp), findsOneWidget);
  });
}
