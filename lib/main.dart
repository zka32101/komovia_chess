import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  // This is required for Firebase configuration
  await dotenv.load(fileName: '.env').catchError(
    (error) {
      // If .env doesn't exist, continue with defaults
      // This allows development/testing to work
      debugPrint('Warning: .env file not found, using defaults. Error: $error');
      return null;
    },
  );

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
