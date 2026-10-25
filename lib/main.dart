import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase/RevenueCat configuration now comes from compile-time
  // --dart-define-from-file=.env (see DefaultFirebaseOptions and
  // RevenueCatConfig) instead of a bundled runtime asset, so there's
  // nothing to load here anymore.

  // Initialize Firebase with configuration from environment
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('Please configure Firebase credentials in .env file');
    // Continue anyway - app can still run without Firebase in development
  }

  // Initialize sound service for audio effects
  try {
    final soundService = SoundService();
    await soundService.initialize();
    debugPrint('✅ SoundService initialized successfully');
  } catch (e) {
    debugPrint('⚠️ SoundService initialization warning: $e');
    // Continue anyway - app can still run without sound
  }

  runApp(
    const ProviderScope(
      child: ChessTacticsMasterApp(),
    ),
  );
}
