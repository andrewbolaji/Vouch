import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/screens/verify_email_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  static bool _isValidEmail(String email) =>
      _emailRegex.hasMatch(email);

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error = 'Please fill in all fields.',
      );
      return;
    }
    if (!_isValidEmail(email)) {
      setState(
        () => _error = 'Please enter a valid email.',
      );
      return;
    }

    final auth = context.read<AuthService>();
    try {
      if (_isSignUp) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() => _error = 'Please enter your name.');
          return;
        }
        await auth.signUpWithEmail(email, password, name);
        if (mounted) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const VerifyEmailScreen(),
            ),
          );
        }
      } else {
        await auth.signInWithEmail(email, password);
        if (mounted) {
          if (auth.currentUser?.needsEmailVerification ?? false) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => const VerifyEmailScreen(),
              ),
            );
          } else {
            Navigator.of(context).pop();
          }
        }
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthService>();
    try {
      await auth.signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _handleAppleSignIn() async {
    final auth = context.read<AuthService>();
    try {
      await auth.signInWithApple();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isSignUp ? 'Create Account' : 'Sign In',
          style: AppTheme.headlineLarge,
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSignUp
                  ? 'Join the locals who decide the rankings.'
                  : 'Good to see you.',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            // Social sign-in buttons
            _SocialButton(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata,
              onTap: auth.isLoading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _SocialButton(
              label: 'Continue with Apple',
              icon: Icons.apple,
              onTap: auth.isLoading ? null : _handleAppleSignIn,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: AppTheme.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                  ),
                  child: Text('or', style: AppTheme.bodySmall),
                ),
                Expanded(child: Divider(color: AppTheme.divider)),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),
            // Email fields
            if (_isSignUp) ...[
              _InputField(
                controller: _nameController,
                hint: 'Your name',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spacingMd),
            ],
            _InputField(
              controller: _emailController,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _InputField(
              controller: _passwordController,
              hint: 'Password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitEmail(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                _error!,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _submitEmail,
              style: AppTheme.accentButtonStyle,
              child: auth.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.onAccent,
                        ),
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: AppTheme.buttonText.copyWith(
                        color: AppTheme.onAccent,
                      ),
                    ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label, style: AppTheme.buttonText),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: BorderSide(color: AppTheme.divider),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.bodyMedium,
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
      ),
    );
  }
}
