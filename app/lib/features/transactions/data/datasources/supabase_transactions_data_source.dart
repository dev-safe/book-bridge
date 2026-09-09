import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTransactionsDataSource {
  final SupabaseClient supabaseClient;
  SupabaseTransactionsDataSource({required this.supabaseClient});

  Future<List<TransactionEntity>> getPurchases(String userId) async {
    try {
      final response = await supabaseClient
          .from('transactions')
          .select(
            'id, listing_id, buyer_id, seller_id, amount, status, external_ref:payment_reference, created_at, '
            'listings(title, image_url)',
          )
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => _fromJson(json)).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch purchases: $e');
    }
  }

  Future<List<TransactionEntity>> getSales(String userId) async {
    try {
      final response = await supabaseClient
          .from('transactions')
          .select(
            'id, listing_id, buyer_id, seller_id, amount, status, external_ref:payment_reference, created_at, '
            'listings(title, image_url)',
          )
          .eq('seller_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => _fromJson(json)).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch sales: $e');
    }
  }

  Future<TransactionEntity> getTransactionByExternalRef(
    String externalRef,
  ) async {
    try {
      final response = await supabaseClient
          .from('transactions')
          .select(
            'id, listing_id, buyer_id, seller_id, amount, status, external_ref:payment_reference, created_at, '
            'listings(title, image_url)',
          )
          .eq('payment_reference', externalRef)
          .single();

      return _fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to fetch transaction: $e');
    }
  }

  Future<void> confirmReceipt(String transactionId) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'process-escrow',
        body: {'action': 'release', 'transaction_id': transactionId},
      );
      if (response.status != 200) {
        throw ServerException(
          message: 'Failed to confirm receipt: ${response.data}',
        );
      }
    } catch (e) {
      throw ServerException(message: 'Failed to confirm receipt: $e');
    }
  }

  Future<void> disputeTransaction(String transactionId, String reason) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'process-escrow',
        body: {
          'action': 'dispute',
          'transaction_id': transactionId,
          'dispute_reason': reason,
        },
      );
      if (response.status != 200) {
        throw ServerException(
          message: 'Failed to dispute transaction: ${response.data}',
        );
      }
    } catch (e) {
      throw ServerException(message: 'Failed to dispute transaction: $e');
    }
  }

  TransactionEntity _fromJson(Map<String, dynamic> json) {
    final listing = json['listings'] as Map<String, dynamic>? ?? {};
    return TransactionEntity(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      listingTitle: listing['title'] as String? ?? 'Unknown Book',
      listingImageUrl: listing['image_url'] as String? ?? '',
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      amountFcfa: (json['amount'] as num).toInt(),
      status: json['status'] as String? ?? 'pending',
      externalRef: json['external_ref'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
