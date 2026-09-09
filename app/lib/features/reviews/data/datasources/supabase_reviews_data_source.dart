import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';

abstract class ReviewsDataSource {
  Future<void> createReview(ReviewEntity review);
  Future<List<ReviewEntity>> getUserReviews(String userId);
  Future<bool> hasReviewed(String transactionId, String reviewerId);
}

class SupabaseReviewsDataSource implements ReviewsDataSource {
  final SupabaseClient supabase;

  SupabaseReviewsDataSource(this.supabase);

  @override
  Future<void> createReview(ReviewEntity review) async {
    await supabase.from('reviews').insert({
      'reviewer_id': review.reviewerId,
      'reviewee_id': review.revieweeId,
      'listing_id': review.listingId,
      'transaction_id': review.transactionId,
      'rating': review.rating,
      'comment': review.comment,
    });
  }

  @override
  Future<List<ReviewEntity>> getUserReviews(String userId) async {
    final response = await supabase
        .from('reviews')
        .select()
        .eq('reviewee_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((data) => _mapToEntity(data)).toList();
  }

  @override
  Future<bool> hasReviewed(String transactionId, String reviewerId) async {
    final response = await supabase
        .from('reviews')
        .select('id')
        .eq('transaction_id', transactionId)
        .eq('reviewer_id', reviewerId)
        .maybeSingle();

    return response != null;
  }

  ReviewEntity _mapToEntity(Map<String, dynamic> data) {
    return ReviewEntity(
      id: data['id'],
      reviewerId: data['reviewer_id'],
      revieweeId: data['reviewee_id'],
      listingId: data['listing_id'],
      transactionId: data['transaction_id'],
      rating: data['rating'],
      comment: data['comment'],
      createdAt: DateTime.parse(data['created_at']),
    );
  }
}
