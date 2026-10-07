import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Analytics Tests', () {
    group('Event Validation', () {
      bool isValidEventName(String name) {
        return name.isNotEmpty && name.length <= 40;
      }

      test('Valid event names', () {
        expect(isValidEventName('game_started'), true);
        expect(isValidEventName('user_sign_up'), true);
        expect(isValidEventName('screen_viewed'), true);
      });

      test('Empty event name invalid', () {
        expect(isValidEventName(''), false);
      });

      test('Event name too long invalid', () {
        final longName = 'x' * 50;
        expect(isValidEventName(longName), false);
      });
    });

    group('Session Tracking', () {
      String generateSessionId() {
        return 'session_${DateTime.now().millisecondsSinceEpoch}';
      }

      test('Session ID generated', () {
        final sessionId = generateSessionId();
        expect(sessionId, isNotEmpty);
        expect(sessionId, startsWith('session_'));
      });

      test('Unique session IDs', () {
        final id1 = generateSessionId();
        final id2 = generateSessionId();
        expect(id1, isNot(id2));
      });
    });

    group('User Properties', () {
      Map<String, String> userProperties = {};

      void setUserProperty(String key, String value) {
        userProperties[key] = value;
      }

      test('Set user property', () {
        setUserProperty('subscription_tier', 'premium');
        expect(userProperties['subscription_tier'], 'premium');
      });

      test('Update user property', () {
        setUserProperty('game_count', '10');
        expect(userProperties['game_count'], '10');

        setUserProperty('game_count', '11');
        expect(userProperties['game_count'], '11');
      });
    });

    group('Game Analytics', () {
      Map<String, dynamic> createGameEvent({
        required bool won,
        required int duration,
        required int moves,
      }) {
        return {
          'won': won,
          'duration_ms': duration,
          'move_count': moves,
        };
      }

      test('Win event', () {
        final event = createGameEvent(won: true, duration: 300000, moves: 45);

        expect(event['won'], true);
        expect(event['duration_ms'], 300000);
        expect(event['move_count'], 45);
      });

      test('Loss event', () {
        final event = createGameEvent(won: false, duration: 150000, moves: 25);

        expect(event['won'], false);
        expect(event['duration_ms'], 150000);
      });
    });

    group('Screen View Tracking', () {
      List<String> screensViewed = [];

      void trackScreenView(String screenName) {
        screensViewed.add(screenName);
      }

      test('Track single screen view', () {
        trackScreenView('home');
        expect(screensViewed, ['home']);
      });

      test('Track multiple screen views', () {
        screensViewed.clear();
        trackScreenView('home');
        trackScreenView('leaderboard');
        trackScreenView('settings');

        expect(screensViewed.length, 3);
        expect(screensViewed.last, 'settings');
      });
    });

    group('Error Tracking', () {
      List<Map<String, String>> errors = [];

      void trackError(String code, String message) {
        errors.add({'code': code, 'message': message});
      }

      test('Log error event', () {
        trackError('AUTH_001', 'Invalid credentials');

        expect(errors.length, 1);
        expect(errors[0]['code'], 'AUTH_001');
      });

      test('Multiple error tracking', () {
        errors.clear();
        trackError('NET_001', 'Network timeout');
        trackError('GAME_001', 'Invalid move');

        expect(errors.length, 2);
      });
    });

    group('Purchase Analytics', () {
      Map<String, dynamic> createPurchaseEvent({
        required String productId,
        required double price,
        required String currency,
      }) {
        return {
          'product_id': productId,
          'price': price,
          'currency': currency,
        };
      }

      test('Premium subscription purchase', () {
        final event = createPurchaseEvent(
          productId: 'premium_monthly',
          price: 4.99,
          currency: 'USD',
        );

        expect(event['product_id'], 'premium_monthly');
        expect(event['price'], 4.99);
      });

      test('Elite subscription purchase', () {
        final event = createPurchaseEvent(
          productId: 'elite_monthly',
          price: 9.99,
          currency: 'USD',
        );

        expect(event['price'], 9.99);
      });
    });

    group('Retention Metrics', () {
      int calculateDaysSinceLastActive(DateTime lastActive) {
        return DateTime.now().difference(lastActive).inDays;
      }

      test('Active today', () {
        final today = DateTime.now();
        final days = calculateDaysSinceLastActive(today);

        expect(days, 0);
      });

      test('Inactive 7 days', () {
        final weekAgo = DateTime.now().subtract(Duration(days: 7));
        final days = calculateDaysSinceLastActive(weekAgo);

        expect(days, 7);
      });

      test('Churn detection (30+ days)', () {
        final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
        final days = calculateDaysSinceLastActive(thirtyDaysAgo);
        final isChurned = days >= 30;

        expect(isChurned, true);
      });
    });
  });
}
