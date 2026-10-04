import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticated JSON client for the BookBridge Rust core service.
///
/// Every request carries the signed-in user's Supabase access token. A 401
/// becomes [AuthAppException]; other failures become [ServerException] with
/// the service's `{"error": ...}` message when it sends one.
class RustCoreClient {
  /// Render's free tier can take close to a minute to wake from sleep.
  static const Duration timeout = Duration(seconds: 90);

  final String baseUrl;
  final http.Client _http;
  final Future<String?> Function() _accessToken;

  RustCoreClient({
    required String baseUrl,
    required Future<String?> Function() accessToken,
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client(),
       _accessToken = accessToken;

  /// Uses the current Supabase session, refreshing it first if it has expired.
  factory RustCoreClient.forSupabase({
    required SupabaseClient supabaseClient,
    required String baseUrl,
    http.Client? httpClient,
  }) {
    return RustCoreClient(
      baseUrl: baseUrl,
      httpClient: httpClient,
      accessToken: () async {
        var session = supabaseClient.auth.currentSession;
        if (session != null && session.isExpired) {
          session = (await supabaseClient.auth.refreshSession()).session;
        }
        return session?.accessToken;
      },
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    required String failurePrefix,
  }) {
    return _send(
      (uri, headers) => _http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      path,
      failurePrefix,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    required String failurePrefix,
  }) {
    return _send(
      (uri, headers) => _http.get(uri, headers: headers),
      path,
      failurePrefix,
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Uri uri, Map<String, String> headers)
    request,
    String path,
    String failurePrefix,
  ) async {
    try {
      final token = await _accessToken();
      if (token == null || token.isEmpty) {
        throw AuthAppException(message: 'Please sign in again to continue.');
      }

      final response = await request(Uri.parse('$baseUrl$path'), {
        'Authorization': 'Bearer $token',
      }).timeout(timeout);

      if (response.statusCode == 401) {
        throw AuthAppException(
          message: 'Your session has expired. Please sign in again.',
        );
      }
      if (response.statusCode != 200) {
        throw ServerException(
          message: '$failurePrefix: ${_errorMessage(response)}',
        );
      }
      final decoded = jsonDecode(_utf8Body(response));
      if (decoded is! Map<String, dynamic>) {
        throw ServerException(message: '$failurePrefix: unexpected response');
      }
      return decoded;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: '$failurePrefix: $e');
    }
  }

  /// JSON is always UTF-8, but `response.body` falls back to Latin-1 when the
  /// server sends no charset (Axum doesn't), garbling accented names.
  static String _utf8Body(http.Response response) =>
      utf8.decode(response.bodyBytes, allowMalformed: true);

  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(_utf8Body(response));
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Non-JSON body (e.g. a proxy error page); fall through.
    }
    return 'Request failed (${response.statusCode})';
  }
}
