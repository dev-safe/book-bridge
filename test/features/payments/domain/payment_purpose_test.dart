import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase and boost send only the listing id', () {
    expect(const PurchasePayment('l1').toJson(), {
      'kind': 'purchase',
      'listing_id': 'l1',
    });
    expect(const BoostPayment('l1').toJson(), {
      'kind': 'boost',
      'listing_id': 'l1',
    });
  });

  test('donation sends its amount', () {
    expect(const DonationPayment(1000).toJson(), {
      'kind': 'donation',
      'amount': 1000,
    });
  });
}
