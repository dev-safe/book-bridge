import 'dart:convert';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:http/http.dart' as http;

class FapshiDataSource {
  final String apiUser;
  final String apiKey;
  final String baseUrl;

  FapshiDataSource({
    required this.apiUser,
    required this.apiKey,
    this.baseUrl = 'https://api.fapshi.com',
  });

  /// Initiates a direct payment via Mobile Money.
  Future<Map<String, dynamic>> directPay({
    required int amount,
    required String phone,
    required String externalId,
    required String medium,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/direct-pay'),
            headers: {
              'Content-Type': 'application/json',
              'apiuser': apiUser,
              'apikey': apiKey,
            },
            body: jsonEncode({
              'amount': amount,
              'phone': phone,
              'externalId': externalId,
              'medium': medium,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw ServerException(
          message:
              'Fapshi direct pay failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Fapshi Network Error: $e');
    }
  }

  /// Checks the status of a transaction.
  Future<Map<String, dynamic>> paymentStatus(String transId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment-status/$transId'),
        headers: {'apiuser': apiUser, 'apikey': apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw ServerException(
          message:
              'Fapshi Status Check failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Fapshi Status Check Error: $e');
    }
  }
}
