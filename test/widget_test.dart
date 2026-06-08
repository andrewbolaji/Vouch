import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/services/auth_service.dart';

void main() {
  testWidgets('App launches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService.mock();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AppState(useFirebase: false),
          ),
          ChangeNotifierProvider(create: (_) => MembershipProvider()),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => SavedProvider(authService: auth),
          ),
          ChangeNotifierProvider(
            create: (_) => SuggestionProvider(authService: auth),
          ),
        ],
        child: const MaterialApp(home: Scaffold()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
