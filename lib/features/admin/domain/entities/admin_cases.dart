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

/// A user's ID photos waiting for an admin to approve or reject them.
class IdVerificationSubmission {
  final String userId;
  final String? fullName;
  final DateTime? dateOfBirth;
  final int? age;

  /// `school_id` (ages 10-17) or `cni` (18+).
  final String? idType;

  /// Masked guardian MoMo number, set for users aged 10-14.
  final String? guardianPhoneHint;

  /// Object paths in the private `id-documents` bucket.
  final List<String> documentPaths;
  final DateTime? submittedAt;

  const IdVerificationSubmission({
    required this.userId,
    this.fullName,
    this.dateOfBirth,
    this.age,
    this.idType,
    this.guardianPhoneHint,
    this.documentPaths = const [],
    this.submittedAt,
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

/// An open user report about a listing or a user.
class ContentReport {
  final String id;

  /// One of spam, scam, inappropriate, harassment, prohibited, other.
  final String reason;
  final String? details;
  final DateTime? createdAt;
  final String? reporterName;
  final String? listingId;
  final String? listingTitle;
  final String? listingStatus;

  /// The reported user, or the seller of the reported listing.
  final String? reportedUserId;
  final String? reportedUserName;

  const ContentReport({
    required this.id,
    required this.reason,
    this.details,
    this.createdAt,
    this.reporterName,
    this.listingId,
    this.listingTitle,
    this.listingStatus,
    this.reportedUserId,
    this.reportedUserName,
  });

  bool get isAboutListing => listingId != null;
}
