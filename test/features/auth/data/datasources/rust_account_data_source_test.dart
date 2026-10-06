import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/auth/data/datasources/rust_account_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  RustAccountDataSource build(http.Response Function(http.Request) respond) {
    requests = [];
    return RustAccountDataSource(
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

  test('posts to /account/delete with the bearer token', () async {
    final ds = build((_) => json({'ok': true}));

    await ds.deleteAccount();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/account/delete');
    expect(requests.single.headers['Authorization'], 'Bearer access-token');
  });

  test('a 409 (order in progress) becomes a ConflictException', () async {
    final ds = build(
      (_) => json({'error': 'You have an order in progress.'}, 409),
    );

    await expectLater(
      ds.deleteAccount(),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('order in progress'),
        ),
      ),
    );
  });

  test('other failures stay plain ServerExceptions', () async {
    final ds = build((_) => json({'error': 'Storage is down'}, 502));

    await expectLater(
      ds.deleteAccount(),
      throwsA(allOf(isA<ServerException>(), isNot(isA<ConflictException>()))),
    );
  });

  test('a 401 becomes an AuthAppException', () async {
    final ds = build((_) => json({'error': 'Invalid token'}, 401));

    await expectLater(ds.deleteAccount(), throwsA(isA<AuthAppException>()));
  });
}
