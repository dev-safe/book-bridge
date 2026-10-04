/// What a payment is for. The server works out the amount for purchases and
/// boosts, so only a donation carries one.
sealed class PaymentPurpose {
  const PaymentPurpose();

  Map<String, dynamic> toJson();
}

class PurchasePayment extends PaymentPurpose {
  final String listingId;

  const PurchasePayment(this.listingId);

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'purchase',
    'listing_id': listingId,
  };
}

class BoostPayment extends PaymentPurpose {
  final String listingId;

  const BoostPayment(this.listingId);

  @override
  Map<String, dynamic> toJson() => {'kind': 'boost', 'listing_id': listingId};
}

class DonationPayment extends PaymentPurpose {
  final int amount;

  const DonationPayment(this.amount);

  @override
  Map<String, dynamic> toJson() => {'kind': 'donation', 'amount': amount};
}
