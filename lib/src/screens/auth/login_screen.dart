import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';

/// Sign-in screen. Accounts are created and entered only through Google or
/// Apple sign-in (there is no email/password registration or login).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authStateNotifierProvider.notifier);
      await authNotifier.signInWithGoogle();
      // Navigation happens automatically when auth state changes
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        // User cancelled, don't show error
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = _extractErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authStateNotifierProvider.notifier);
      await authNotifier.signInWithApple();
      // Navigation happens automatically when auth state changes
    } catch (e) {
      if (e.toString().contains('cancelled') ||
          e.toString().contains('not available')) {
        // User cancelled or not available, don't show error for cancelled
        if (e.toString().contains('not available')) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).loginAppleNotAvailableError;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = _extractErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  String _extractErrorMessage(String error) {
    final l10n = AppLocalizations.of(context);
    if (error.contains('user-not-found')) {
      return l10n.loginUserNotFoundError;
    } else if (error.contains('wrong-password')) {
      return l10n.loginWrongPasswordError;
    } else if (error.contains('invalid-email')) {
      return l10n.loginInvalidEmailError;
    } else if (error.contains('too-many-requests')) {
      return l10n.loginTooManyRequestsError;
    }
    return l10n.loginGenericError;
  }

  static bool _isApplePlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(l10n.loginTitle),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo/Title
                Text(
                  l10n.loginAppTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.loginAppSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 24),

                if (_isLoading) ...[
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 24),
                ],

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Text('🔵'),
                    label: Text(l10n.loginSignInWithGoogleButton),
                  ),
                ),

                // Apple Sign-In button. Apple sign-in on Android needs an Apple
                // Services ID + redirect URL that this app does not have, so
                // the button is only offered on Apple platforms.
                if (_isApplePlatform(context)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                      icon: const Text('🍎'),
                      label: Text(l10n.loginSignInWithAppleButton),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }
}
