import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';

/// Admin endpoints of the Rust core service. The service checks that the
/// signed-in user is in `admin_users` on every call.
class RustAdminDataSource {
  final RustCoreClient _client;

  /// Returns a short-lived URL for a photo in the private `id-documents`
  /// bucket; Storage only signs it for admins.
  final Future<String> Function(String path)? _signIdPhoto;

  RustAdminDataSource(
    this._client, {
    Future<String> Function(String path)? signIdPhoto,
  }) : _signIdPhoto = signIdPhoto;

  /// Completes normally only for admins; anyone else gets a [ServerException].
  Future<void> checkAdmin() async {
    final body = await _client.get(
      '/admin/me',
      failurePrefix: 'Admin access check failed',
    );
    if (body['admin'] != true) {
      throw ServerException(message: 'Admin access required');
    }
  }

  Future<List<AdminDispute>> disputes() async {
    final body = await _client.get(
      '/admin/disputes',
      failurePrefix: 'Could not load disputes',
    );
    return _list(body, 'disputes').map(_dispute).toList();
  }

  Future<List<UnmatchedPayment>> unmatchedPayments() async {
    final body = await _client.get(
      '/admin/unmatched-payments',
      failurePrefix: 'Could not load unmatched payments',
    );
    return _list(body, 'payments').map(_unmatched).toList();
  }

  Future<void> releaseDispute(String transactionId, String note) {
    return _resolve(
      '/admin/disputes/${Uri.encodeComponent(transactionId)}/release',
      note,
      failurePrefix: 'Release failed',
    );
  }

  Future<void> refundDispute(
    String transactionId,
    String note, {
    String? phone,
  }) {
    return _resolve(
      '/admin/disputes/${Uri.encodeComponent(transactionId)}/refund',
      note,
      phone: phone,
      failurePrefix: 'Refund failed',
    );
  }

  Future<void> refundUnmatched(String id, String note, {String? phone}) {
    return _resolve(
      '/admin/unmatched-payments/${Uri.encodeComponent(id)}/refund',
      note,
      phone: phone,
      failurePrefix: 'Refund failed',
    );
  }

  Future<void> dismissUnmatched(String id, String note) {
    return _resolve(
      '/admin/unmatched-payments/${Uri.encodeComponent(id)}/dismiss',
      note,
      failurePrefix: 'Dismiss failed',
    );
  }

  Future<List<IdVerificationSubmission>> idVerifications() async {
    final body = await _client.get(
      '/admin/id-verifications',
      failurePrefix: 'Could not load ID submissions',
    );
    return _list(body, 'submissions').map(_submission).toList();
  }

  Future<void> approveId(String userId, String note) {
    return _resolve(
      '/admin/id-verifications/${Uri.encodeComponent(userId)}/approve',
      note,
      failurePrefix: 'Approve failed',
    );
  }

  Future<void> rejectId(String userId, String note) {
    return _resolve(
      '/admin/id-verifications/${Uri.encodeComponent(userId)}/reject',
      note,
      failurePrefix: 'Reject failed',
    );
  }

  Future<String> idPhotoUrl(String path) async {
    final sign = _signIdPhoto;
    if (sign == null) {
      throw ServerException(message: 'ID photos are not available');
    }
    return sign(path);
  }

  Future<void> _resolve(
    String path,
    String note, {
    String? phone,
    required String failurePrefix,
  }) async {
    await _client.post(path, {
      'note': note,
      'phone': ?phone,
    }, failurePrefix: failurePrefix);
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> body,
    String key,
  ) {
    final items = body[key];
    if (items is! List) {
      throw ServerException(message: 'Unexpected response: no $key');
    }
    return items.whereType<Map<String, dynamic>>().toList();
  }

  static AdminDispute _dispute(Map<String, dynamic> json) {
    final id = json['transaction_id'];
    final amount = json['amount'];
    if (id is! String || amount is! num) {
      throw ServerException(message: 'Unexpected dispute in response');
    }
    return AdminDispute(
      transactionId: id,
      amount: amount.toInt(),
      listingTitle: json['listing_title'] as String?,
      buyerName: json['buyer_name'] as String?,
      sellerName: json['seller_name'] as String?,
      disputeReason: json['dispute_reason'] as String?,
      disputedAt: _date(json['disputed_at']),
      payerPhoneHint: json['payer_phone_hint'] as String?,
    );
  }

  static UnmatchedPayment _unmatched(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) {
      throw ServerException(message: 'Unexpected payment in response');
    }
    return UnmatchedPayment(
      id: id,
      transId: json['trans_id'] as String?,
      amount: json['amount'] as num?,
      reason: json['reason'] as String?,
      receivedAt: _date(json['received_at']),
      payerPhoneHint: json['payer_phone_hint'] as String?,
    );
  }

  static IdVerificationSubmission _submission(Map<String, dynamic> json) {
    final id = json['user_id'];
    if (id is! String) {
      throw ServerException(message: 'Unexpected ID submission in response');
    }
    final paths = json['document_paths'];
    final age = json['age'];
    return IdVerificationSubmission(
      userId: id,
      fullName: json['full_name'] as String?,
      dateOfBirth: _date(json['date_of_birth']),
      age: age is num ? age.toInt() : null,
      idType: json['id_type'] as String?,
      guardianPhoneHint: json['guardian_phone_hint'] as String?,
      documentPaths: paths is List
          ? List.unmodifiable(paths.whereType<String>())
          : const [],
      submittedAt: _date(json['submitted_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
