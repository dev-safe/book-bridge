import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/core/utils/listing_share.dart';

/// Power Seller subscription endpoints of the Rust core service.
///
/// Payment happens on the web: the app gets a short-lived one-time code
/// and opens the upgrade page with it.
class RustSubscriptionDataSource {
  final RustCoreClient _client;

  RustSubscriptionDataSource(this._client);

  /// Returns the upgrade page URL with a fresh one-time code.
  Future<Uri> upgradeUrl() async {
    final body = await _client.post(
      '/subscriptions/upgrade-code',
      const {},
      failurePrefix: 'Could not start the upgrade',
    );
    final code = body['code'];
    if (code is! String || code.isEmpty) {
      throw ServerException(message: 'Could not start the upgrade');
    }
    return Uri.parse(
      '$kShareBaseUrl/upgrade',
    ).replace(queryParameters: {'code': code});
  }
}
