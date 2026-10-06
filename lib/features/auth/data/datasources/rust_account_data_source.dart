import 'package:book_bridge/core/network/rust_core_client.dart';

/// Account endpoints of the Rust core service.
class RustAccountDataSource {
  final RustCoreClient _client;

  RustAccountDataSource(this._client);

  /// Permanently deletes the signed-in user's account.
  ///
  /// Throws `ConflictException` while the user has an order in progress.
  Future<void> deleteAccount() async {
    await _client.post(
      '/account/delete',
      const {},
      failurePrefix: 'Could not delete your account',
    );
  }
}
