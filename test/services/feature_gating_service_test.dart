import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/feature_gating_service.dart';

void main() {
  group('FeatureGatingService', () {
    late FeatureGatingService featureGating;

    setUp(() {
      featureGating = FeatureGatingService.instance;
    });

    group('Feature tier access', () {
      test('free tier has no premium features', () async {
        final hasUnlimitedPuzzles = await featureGating.hasFeatureAccess(
          'unlimited_puzzles',
          'free',
        );
        expect(hasUnlimitedPuzzles, false);

        final hasAdvancedAnalysis = await featureGating.hasFeatureAccess(
          'advanced_analysis',
          'free',
        );
        expect(hasAdvancedAnalysis, false);
      });

      test('pro tier has basic premium features', () async {
        final hasUnlimitedPuzzles = await featureGating.hasFeatureAccess(
          'unlimited_puzzles',
          'pro',
        );
        expect(hasUnlimitedPuzzles, true);

        final hasUnlimitedGames = await featureGating.hasFeatureAccess(
          'unlimited_games',
          'pro',
        );
        expect(hasUnlimitedGames, true);

        // But not premium-only features
        final hasAILessons = await featureGating.hasFeatureAccess(
          'ai_lessons',
          'pro',
        );
        expect(hasAILessons, false);
      });

      test('premium tier has all features', () async {
        final features = [
          'unlimited_puzzles',
          'unlimited_games',
          'advanced_analysis',
          'ai_lessons',
          'personalized_training',
          'offline_mode',
          'priority_support',
        ];

        for (final feature in features) {
          final hasAccess =
              await featureGating.hasFeatureAccess(feature, 'premium');
          expect(hasAccess, true, reason: 'Premium should have $feature');
        }
      });
    });

    group('Daily limit tracking', () {
      test('free tier has daily puzzle limit', () async {
        final remaining = await featureGating.getRemainingDailyAttempts(
          'puzzles',
          'free',
        );
        expect(remaining, 3); // Free tier daily limit
      });

      test('free tier has daily game limit', () async {
        final remaining = await featureGating.getRemainingDailyAttempts(
          'games',
          'free',
        );
        expect(remaining, 2); // Free tier daily limit
      });

      test('pro tier has unlimited attempts', () async {
        final puzzles = await featureGating.getRemainingDailyAttempts(
          'puzzles',
          'pro',
        );
        expect(puzzles, 999); // Unlimited

        final games = await featureGating.getRemainingDailyAttempts(
          'games',
          'pro',
        );
        expect(games, 999); // Unlimited
      });

      test('premium tier has unlimited attempts', () async {
        final puzzles = await featureGating.getRemainingDailyAttempts(
          'puzzles',
          'premium',
        );
        expect(puzzles, 999);

        final games = await featureGating.getRemainingDailyAttempts(
          'games',
          'premium',
        );
        expect(games, 999);
      });
    });

    group('Action permission checking', () {
      test('free user can perform action with remaining attempts', () async {
        final canPerform =
            await featureGating.canPerformAction('puzzles', 'free');
        expect(canPerform, true);
      });

      test('pro user can always perform action', () async {
        final canPerform =
            await featureGating.canPerformAction('puzzles', 'pro');
        expect(canPerform, true);

        final canPerformGames =
            await featureGating.canPerformAction('games', 'pro');
        expect(canPerformGames, true);
      });

      test('premium user can always perform action', () async {
        final canPerform =
            await featureGating.canPerformAction('puzzles', 'premium');
        expect(canPerform, true);
      });
    });

    group('Feature descriptions', () {
      test('provides descriptions for all features', () {
        final features = [
          'unlimited_puzzles',
          'unlimited_games',
          'advanced_analysis',
          'ai_lessons',
          'personalized_training',
          'offline_mode',
          'priority_support',
        ];

        for (final feature in features) {
          final description = featureGating.getFeatureDescription(feature);
          expect(description, isNotEmpty);
        }
      });

      test('returns empty description for unknown feature', () {
        final description =
            featureGating.getFeatureDescription('unknown_feature');
        expect(description, isEmpty);
      });
    });

    group('Tier constants', () {
      test('has correct feature tier mappings', () {
        expect(
          FeatureGatingService.FEATURE_TIERS['unlimited_puzzles'],
          contains('pro'),
        );
        expect(
          FeatureGatingService.FEATURE_TIERS['unlimited_puzzles'],
          contains('premium'),
        );
      });

      test('has correct daily limits', () {
        expect(FeatureGatingService.DAILY_LIMITS['puzzles'], 3);
        expect(FeatureGatingService.DAILY_LIMITS['games'], 2);
      });
    });

    group('Singleton pattern', () {
      test('returns same instance', () {
        final instance1 = FeatureGatingService.instance;
        final instance2 = FeatureGatingService.instance;

        expect(identical(instance1, instance2), true);
      });
    });
  });
}
