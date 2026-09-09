import 'package:equatable/equatable.dart';

class ReviewEntity extends Equatable {
  final String id;
  final String reviewerId;
  final String revieweeId;
  final String listingId;
  final String transactionId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewEntity({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.listingId,
    required this.transactionId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    reviewerId,
    revieweeId,
    listingId,
    transactionId,
    rating,
    comment,
    createdAt,
  ];
}
