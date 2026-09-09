import 'package:equatable/equatable.dart';

/// Represents a completed marketplace transaction.
class TransactionEntity extends Equatable {
  final String id;
  final String listingId;
  final String listingTitle;
  final String listingImageUrl;
  final String buyerId;
  final String sellerId;
  final int amountFcfa;
  final String status; // 'pending', 'successful', 'failed', 'held', 'disputed'
  final String externalRef;
  final DateTime createdAt;

  const TransactionEntity({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingImageUrl,
    required this.buyerId,
    required this.sellerId,
    required this.amountFcfa,
    required this.status,
    required this.externalRef,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    listingId,
    listingTitle,
    listingImageUrl,
    buyerId,
    sellerId,
    amountFcfa,
    status,
    externalRef,
    createdAt,
  ];
}
