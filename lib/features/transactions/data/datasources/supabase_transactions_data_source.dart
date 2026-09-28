import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AccessTokenProvider = Future<String?> Function();

class SupabaseTransactionsDataSource {
  /// Render's free tier can take close to a minute to wake from sleep.
  static const Duration rustCoreTimeout = Duration(seconds: 90);

  final SupabaseClient supabaseClient;
  final String rustCoreUrl;
  final http.Client _http;
  final AccessTokenProvider _accessToken;

  SupabaseTransactionsDataSource({
    required this.supabaseClient,
    required String rustCoreUrl,
    http.Client? httpClient,
    AccessTokenProvider? accessToken,
  }) : rustCoreUrl = rustCoreUrl.replaceAll(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client(),
       _accessToken = accessToken ?? _sessionAccessToken(supabaseClient);

  static AccessTokenProvider _sessionAccessToken(SupabaseClient client) {
    return () async {
      var session = client.auth.currentSession;
      if (session != null && session.isExpired) {
        session = (await client.auth.refreshSession()).session;
      }
      return session?.accessToken;
    };
  }

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

  Future<void> confirmReceipt(String transactionId) {
    return _postEscrowAction('/escrow/confirm-receipt', {
      'transaction_id': transactionId,
    }, failurePrefix: 'Failed to confirm receipt');
  }

  Future<void> disputeTransaction(String transactionId, String reason) {
    return _postEscrowAction('/escrow/dispute', {
      'transaction_id': transactionId,
      'dispute_reason': reason,
    }, failurePrefix: 'Failed to dispute transaction');
  }

  Future<void> _postEscrowAction(
    String path,
    Map<String, dynamic> body, {
    required String failurePrefix,
  }) async {
    try {
      final token = await _accessToken();
      if (token == null || token.isEmpty) {
        throw AuthAppException(message: 'Please sign in again to continue.');
      }

      final response = await _http
          .post(
            Uri.parse('$rustCoreUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(rustCoreTimeout);

      if (response.statusCode == 200) return;
      if (response.statusCode == 401) {
        throw AuthAppException(
          message: 'Your session has expired. Please sign in again.',
        );
      }
      throw ServerException(
        message: '$failurePrefix: ${_errorMessage(response)}',
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: '$failurePrefix: $e');
    }
  }

  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Non-JSON body (e.g. a proxy error page); fall through.
    }
    return 'Request failed (${response.statusCode})';
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
