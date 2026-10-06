import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const fakeUserId = 'aaaaaaaa-1111-4222-8333-444444444444';

/// A real [SupabaseClient] whose HTTP goes to [httpClient], optionally
/// signed in as [fakeUserId] without touching the network. Lets tests check
/// the PostgREST requests a data source builds.
Future<SupabaseClient> fakeSupabaseClient(
  http.Client httpClient, {
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'https://test.supabase.co',
    'test-anon-key',
    httpClient: httpClient,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (signedIn) {
    final exp = DateTime.now().add(const Duration(hours: 1));
    final expSeconds = exp.millisecondsSinceEpoch ~/ 1000;
    String part(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final token =
        '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${part({'sub': fakeUserId, 'exp': expSeconds, 'role': 'authenticated'})}.'
        'signature';
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': expSeconds,
        'refresh_token': 'refresh',
        'user': {
          'id': fakeUserId,
          'aud': 'authenticated',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }
  return client;
}

/// An HTTP client that records each request into [requests] and answers
/// with [respond]. PostgREST reads the request back from the response, so
/// it is attached here.
http.Client recordingHttpClient(
  List<http.Request> requests,
  http.Response Function(http.Request request) respond,
) => MockClient((request) async {
  requests.add(request);
  final response = respond(request);
  return http.Response.bytes(
    response.bodyBytes,
    response.statusCode,
    headers: response.headers,
    request: request,
  );
});

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
