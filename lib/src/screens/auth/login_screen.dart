import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/validation_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    required this.onSignUpTap,
    Key? key,
  }) : super(key: key);
  final VoidCallback onSignUpTap;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).loginFillAllFieldsError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authStateNotifierProvider.notifier);
      await authNotifier.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigation happens automatically when auth state changes
    } on ValidationException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _extractErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  void _showForgotPasswordDialog() {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String? dialogError;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.loginResetPasswordTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.loginResetPasswordDescription),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                enabled: !isSending,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.loginEmailLabel,
                  hintText: l10n.loginEmailHint,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.loginCancelButton),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      if (email.isEmpty) {
                        setDialogState(() {
                          dialogError = l10n.loginEnterEmailError;
                        });
                        return;
                      }
                      setDialogState(() {
                        isSending = true;
                        dialogError = null;
                      });
                      try {
                        await ref
                            .read(authStateNotifierProvider.notifier)
                            .sendPasswordResetEmail(email);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.loginPasswordResetSentMessage(email),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSending = false;
                          dialogError = _extractErrorMessage(e.toString());
                        });
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.loginSendLinkButton),
            ),
          ],
        ),
      ),
    );
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

                // Email field
                TextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.loginEmailLabel,
                    hintText: l10n.loginEmailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: l10n.loginPasswordLabel,
                    hintText: l10n.loginPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: Text(l10n.loginForgotPasswordButton),
                  ),
                ),
                const SizedBox(height: 24),

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

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.loginSignInButton),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.loginNoAccountPrompt),
                    TextButton(
                      onPressed: _isLoading ? null : widget.onSignUpTap,
                      child: Text(l10n.loginSignUpButton),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.loginOrDivider,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

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
                const SizedBox(height: 12),

                // Apple Sign-In button
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
            ),
          ),
        ),
      );
  }
}
