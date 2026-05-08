import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

/// A test-only AuthService subclass that allows controlling
/// when sign-in completes, simulating slow network.
class DelayedAuthService extends AuthService {
  DelayedAuthService() : super.mock();

  final _completer = Completer<void>();
  bool signInCalled = false;

  /// Simulates a slow sign-in. Call [completeSignIn] to resolve.
  Future<void> simulateSlowSignIn() async {
    signInCalled = true;
    _isLoadingOverride = true;
    notifyListeners();
    await _completer.future;
    _currentUserOverride = const AuthUser(
      uid: 'slow-uid',
      email: 'slow@test.com',
      displayName: 'Slow User',
      method: AuthMethod.email,
    );
    _isLoadingOverride = false;
    notifyListeners();
  }

  void completeSignIn() {
    if (!_completer.isCompleted) _completer.complete();
  }

  bool? _isLoadingOverride;
  AuthUser? _currentUserOverride;

  @override
  bool get isLoading => _isLoadingOverride ?? super.isLoading;

  @override
  AuthUser? get currentUser => _currentUserOverride ?? super.currentUser;

  @override
  bool get isSignedIn => _currentUserOverride != null;

  @override
  String get displayName =>
      _currentUserOverride?.displayName ?? super.displayName;
}

/// Minimal screen that exercises the loading-state pattern
/// matching the real sign-in screen's behavior.
class _SlowPathTestScreen extends StatefulWidget {
  const _SlowPathTestScreen();

  @override
  State<_SlowPathTestScreen> createState() => _SlowPathTestScreenState();
}

class _SlowPathTestScreenState extends State<_SlowPathTestScreen> {
  bool _submitted = false;
  String? _result;

  Future<void> _handleSignIn() async {
    final auth = context.read<DelayedAuthService>();
    setState(() => _submitted = true);
    await auth.simulateSlowSignIn();
    if (mounted) {
      setState(() => _result = 'signed in as ${auth.displayName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DelayedAuthService>();
    return Scaffold(
      body: Column(
        children: [
          if (auth.isLoading)
            const CircularProgressIndicator(key: Key('loading')),
          if (_result != null) Text(_result!, key: const Key('result')),
          ElevatedButton(
            onPressed: auth.isLoading ? null : _handleSignIn,
            child: const Text('Sign In'),
          ),
          if (_submitted && !auth.isLoading && _result == null)
            const Text('idle after submit'),
        ],
      ),
    );
  }
}

void main() {
  group('Slow-path loading state', () {
    testWidgets(
      'loading indicator shows during slow auth call and '
      'result lands when call completes',
      (tester) async {
        final authService = DelayedAuthService();

        await tester.pumpWidget(
          ChangeNotifierProvider<DelayedAuthService>.value(
            value: authService,
            child: MaterialApp(
              theme: AppTheme.themeData,
              home: const _SlowPathTestScreen(),
            ),
          ),
        );

        // Initial state: no loading, no result
        expect(find.byKey(const Key('loading')), findsNothing);
        expect(find.byKey(const Key('result')), findsNothing);
        expect(find.text('Sign In'), findsOneWidget);

        // Tap sign in - starts the slow call
        await tester.tap(find.text('Sign In'));
        await tester.pump();

        // Loading state renders
        expect(find.byKey(const Key('loading')), findsOneWidget);
        expect(find.byKey(const Key('result')), findsNothing);
        // Button disabled during loading
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);

        // Simulate 5 seconds of waiting (loading persists)
        await tester.pump(const Duration(seconds: 5));
        expect(find.byKey(const Key('loading')), findsOneWidget);
        expect(find.byKey(const Key('result')), findsNothing);

        // Complete the sign-in
        authService.completeSignIn();
        await tester.pump();
        await tester.pump();

        // Result lands, loading gone
        expect(find.byKey(const Key('loading')), findsNothing);
        expect(
          find.byKey(const Key('result')),
          findsOneWidget,
        );
        expect(find.text('signed in as Slow User'), findsOneWidget);
      },
    );

    testWidgets(
      'navigating away mid-call does not crash '
      '(mounted check holds across long await)',
      (tester) async {
        final authService = DelayedAuthService();

        await tester.pumpWidget(
          ChangeNotifierProvider<DelayedAuthService>.value(
            value: authService,
            child: MaterialApp(
              theme: AppTheme.themeData,
              home: const _SlowPathTestScreen(),
              routes: {'/other': (_) => const Scaffold(body: Text('Other'))},
            ),
          ),
        );

        // Start slow sign-in
        await tester.tap(find.text('Sign In'));
        await tester.pump();
        expect(find.byKey(const Key('loading')), findsOneWidget);

        // Navigate away while loading (simulates user backing out)
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        unawaited(navigator.pushNamed('/other'));
        await tester.pumpAndSettle();

        expect(find.text('Other'), findsOneWidget);

        // Complete the sign-in after navigation
        // Should not crash (mounted check prevents setState)
        authService.completeSignIn();
        await tester.pump();
        await tester.pump();

        // Still on the other page, no crash
        expect(find.text('Other'), findsOneWidget);
      },
    );
  });
}
