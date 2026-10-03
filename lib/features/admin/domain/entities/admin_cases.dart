/// A purchase the buyer disputed, waiting for an admin to pay the seller or
/// refund the buyer.
class AdminDispute {
  final String transactionId;
  final int amount;
  final String? listingTitle;
  final String? buyerName;
  final String? sellerName;
  final String? disputeReason;
  final DateTime? disputedAt;

  /// Masked number the buyer paid from (e.g. `677•••456`), if recorded.
  final String? payerPhoneHint;

  const AdminDispute({
    required this.transactionId,
    required this.amount,
    this.listingTitle,
    this.buyerName,
    this.sellerName,
    this.disputeReason,
    this.disputedAt,
    this.payerPhoneHint,
  });
}

/// A payment Fapshi reported that matched no pending purchase.
class UnmatchedPayment {
  final String id;
  final String? transId;

  /// The amount in the webhook; a refund pays what Fapshi itself recorded.
  final num? amount;
  final String? reason;
  final DateTime? receivedAt;
  final String? payerPhoneHint;

  const UnmatchedPayment({
    required this.id,
    this.transId,
    this.amount,
    this.reason,
    this.receivedAt,
    this.payerPhoneHint,
  });
}
