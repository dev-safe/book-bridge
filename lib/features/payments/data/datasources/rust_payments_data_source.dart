import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';

/// Mobile Money payments through the Rust core service, which holds the
/// Fapshi credentials and decides what each payment costs.
class RustPaymentsDataSource {
  final RustCoreClient _client;

  RustPaymentsDataSource(this._client);

  /// Sends the payment prompt to [phone] and returns Fapshi's transId.
  Future<String> initiate({
    required PaymentPurpose purpose,
    required String phone,
    String? medium,
  }) async {
    final body = await _client.post('/payments/initiate', {
      ...purpose.toJson(),
      'phone': phone,
      'medium': ?medium,
    }, failurePrefix: 'Payment could not be started');
    final transId = body['trans_id'];
    if (transId is! String || transId.isEmpty) {
      throw ServerException(message: 'No transaction ID returned');
    }
    return transId;
  }

  /// Fapshi's status for [transId], e.g. `CREATED`, `SUCCESSFUL`, `FAILED`.
  Future<String> status(String transId) async {
    final body = await _client.get(
      '/payments/status/${Uri.encodeComponent(transId)}',
      failurePrefix: 'Payment status check failed',
    );
    final status = body['status'];
    if (status is! String || status.isEmpty) {
      throw ServerException(message: 'No payment status returned');
    }
    return status;
  }
}
