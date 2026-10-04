import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/subscriptions/data/datasources/rust_subscription_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  RustSubscriptionDataSource build(
    http.Response Function(http.Request) respond,
  ) {
    requests = [];
    return RustSubscriptionDataSource(
      RustCoreClient(
        baseUrl: 'https://rust.example.com',
        accessToken: () async => 'access-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      ),
    );
  }

  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('builds the upgrade URL from a fresh code', () async {
    final ds = build(
      (_) => json({'code': 'abc123', 'expires_at': '2026-01-01T00:00:00Z'}),
    );

    final url = await ds.upgradeUrl();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/subscriptions/upgrade-code');
    expect(requests.single.headers['Authorization'], 'Bearer access-token');
    expect(url.toString(), 'https://bookbridge.devsafe.cm/upgrade?code=abc123');
  });

  test('throws when the response has no code', () async {
    final ds = build((_) => json({}));

    await expectLater(ds.upgradeUrl(), throwsA(isA<ServerException>()));
  });

  test('surfaces the server error message', () async {
    final ds = build((_) => json({'error': 'Too many requests'}, 429));

    await expectLater(
      ds.upgradeUrl(),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('Too many requests'),
        ),
      ),
    );
  });
}
