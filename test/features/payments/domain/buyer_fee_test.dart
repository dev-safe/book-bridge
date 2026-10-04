import 'package:book_bridge/features/payments/domain/entities/buyer_fee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buyerFeeFor', () {
    test('is zero for non-positive prices', () {
      expect(buyerFeeFor(0), 0);
      expect(buyerFeeFor(-50), 0);
    });

    test('is 6% for exact multiples', () {
      expect(buyerFeeFor(100), 6);
      expect(buyerFeeFor(500), 30);
      expect(buyerFeeFor(5000), 300);
    });

    test('rounds fractional fees up, matching the Rust service', () {
      expect(buyerFeeFor(101), 7);
      expect(buyerFeeFor(1), 1);
    });
  });
}
