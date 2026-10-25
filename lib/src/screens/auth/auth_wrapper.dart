import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/notification_overlay.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _showLoginScreen = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        authState.when(
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(title: Text(l10n.authErrorTitle)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(l10n.authErrorMessage(error.toString())),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _showLoginScreen = true;
                      });
                    },
                    child: Text(l10n.authBackToLoginButton),
                  ),
                ],
              ),
            ),
          ),
          data: (user) {
            // If user is logged in, show home screen
            if (user != null) {
              return const HomeScreen();
            }

            // Otherwise show auth screen
            if (_showLoginScreen) {
              return LoginScreen(
                onSignUpTap: () {
                  setState(() {
                    _showLoginScreen = false;
                  });
                },
              );
            } else {
              return RegisterScreen(
                onLoginTap: () {
                  setState(() {
                    _showLoginScreen = true;
                  });
                },
              );
            }
          },
        ),
        // Notification overlay
        const Positioned.fill(
          child: IgnorePointer(
            child: NotificationOverlay(),
          ),
        ),
      ],
    );
  }
}
