/// Service fee the buyer pays on top of the book price. Must match
/// `buyer_fee_for` in bookbridge-rust-core, which decides the real charge.
const int buyerFeePercent = 6;

/// 6% of [price], rounded up to the next whole FCFA.
int buyerFeeFor(int price) {
  if (price <= 0) return 0;
  return (price * buyerFeePercent + 99) ~/ 100;
}
