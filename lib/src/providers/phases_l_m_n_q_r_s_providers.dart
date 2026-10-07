import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streaming_service.dart';
import '../services/offline_service.dart';
import '../services/analytics_advanced_service.dart';
import '../services/monetization_service.dart';
import '../services/security_service.dart';
import '../services/internationalization_service.dart';

// Phase L: ストリーミング
final streamingServiceProvider = Provider((ref) => StreamingService());
final liveStreamsProvider = FutureProvider(
    (ref) => ref.watch(streamingServiceProvider).getLiveStreams());
final videoTutorialsProvider = FutureProvider.family<List<VideoContent>, int>(
    (ref, limit) =>
        ref.watch(streamingServiceProvider).getVideoTutorials(limit));

// Phase M: オフラインモード
final offlineServiceProvider = FutureProvider((ref) async {
  final service = OfflineService();
  await service.initialize();
  return service;
});
final cachedPuzzlesProvider = FutureProvider((ref) async {
  final service = await ref.watch(offlineServiceProvider.future);
  return service.getCachedPuzzles();
});

// Phase N: 高度な分析
final analyticsAdvancedServiceProvider =
    Provider((ref) => AnalyticsAdvancedService());
final openingBookAnalysisProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, ecoCode) => ref
        .watch(analyticsAdvancedServiceProvider)
        .getOpeningBookAnalysis(ecoCode));
final playerAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) =>
        ref.watch(analyticsAdvancedServiceProvider).getPlayerAnalytics(userId));

// Phase Q: マネタイゼーション
final monetizationServiceProvider = Provider((ref) => MonetizationService());
final subscriptionTiersProvider = FutureProvider(
    (ref) => ref.watch(monetizationServiceProvider).getSubscriptionTiers());

// Phase R: セキュリティ
final securityServiceProvider = Provider((ref) => SecurityService());

// Phase S: 国際化
final internationalizationServiceProvider =
    Provider((ref) => InternationalizationService());
final supportedLanguagesProvider = FutureProvider((ref) =>
    ref.watch(internationalizationServiceProvider).getSupportedLanguages());
final translationsProvider = FutureProvider.family<Map<String, String>, String>(
    (ref, languageCode) => ref
        .watch(internationalizationServiceProvider)
        .getTranslations(languageCode));
