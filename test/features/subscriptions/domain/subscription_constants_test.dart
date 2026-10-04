import 'package:book_bridge/features/subscriptions/domain/subscription_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFreeTierLimitError', () {
    test('is true for the bare sentinel', () {
      expect(isFreeTierLimitError(kFreeTierLimitError), isTrue);
    });

    test('is true when the sentinel is wrapped in a server message', () {
      expect(
        isFreeTierLimitError('PostgrestException(message: free_tier_limit)'),
        isTrue,
      );
    });

    test('is false for other messages', () {
      expect(isFreeTierLimitError('network error'), isFalse);
      expect(isFreeTierLimitError(''), isFalse);
    });

    test('is false for null', () {
      expect(isFreeTierLimitError(null), isFalse);
    });
  });
}
