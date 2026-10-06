import 'package:book_bridge/core/constants/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid digital features are off unless explicitly enabled', () {
    // Play Store builds must not sell digital goods outside Play Billing.
    expect(kDigitalPaymentsEnabled, isFalse);
  });
}
