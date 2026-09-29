import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/payments/data/datasources/rust_payments_data_source.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _listingId = '11111111-2222-4333-8444-555555555555';

void main() {
  late List<http.Request> requests;

  RustPaymentsDataSource build(
    http.Response Function(http.Request) respond, {
    String? token = 'access-token',
  }) {
    requests = [];
    return RustPaymentsDataSource(
      RustCoreClient(
        baseUrl: 'https://rust.example.com/',
        accessToken: () async => token,
        httpClient: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      ),
    );
  }

  group('initiate', () {
    test(
      'POSTs the purpose and phone, never an amount for purchases',
      () async {
        final dataSource = build(
          (_) => http.Response(jsonEncode({'trans_id': 'KGEartB8BK'}), 200),
        );

        final transId = await dataSource.initiate(
          purpose: const PurchasePayment(_listingId),
          phone: '677123456',
          medium: 'mobile money',
        );

        expect(transId, 'KGEartB8BK');
        final request = requests.single;
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://rust.example.com/payments/initiate',
        );
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), {
          'kind': 'purchase',
          'listing_id': _listingId,
          'phone': '677123456',
          'medium': 'mobile money',
        });
      },
    );

    test('omits medium when not given', () async {
      final dataSource = build(
        (_) => http.Response(jsonEncode({'trans_id': 'abc'}), 200),
      );

      await dataSource.initiate(
        purpose: const DonationPayment(500),
        phone: '690000000',
      );

      expect(jsonDecode(requests.single.body), {
        'kind': 'donation',
        'amount': 500,
        'phone': '690000000',
      });
    });

    test('surfaces the server error message', () async {
      final dataSource = build(
        (_) => http.Response(
          jsonEncode({'error': 'This listing is no longer available'}),
          409,
        ),
      );

      expect(
        () => dataSource.initiate(
          purpose: const PurchasePayment(_listingId),
          phone: '677123456',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('This listing is no longer available'),
          ),
        ),
      );
    });

    test('maps 401 to an auth error', () async {
      final dataSource = build((_) => http.Response('', 401));

      expect(
        () => dataSource.initiate(
          purpose: const BoostPayment(_listingId),
          phone: '677123456',
        ),
        throwsA(isA<AuthAppException>()),
      );
    });

    test('does not call the server without a session', () async {
      final dataSource = build(
        (_) => http.Response(jsonEncode({'trans_id': 'abc'}), 200),
        token: null,
      );

      await expectLater(
        dataSource.initiate(
          purpose: const DonationPayment(500),
          phone: '677123456',
        ),
        throwsA(isA<AuthAppException>()),
      );
      expect(requests, isEmpty);
    });

    test('rejects a response without a trans_id', () async {
      final dataSource = build((_) => http.Response(jsonEncode({}), 200));

      expect(
        () => dataSource.initiate(
          purpose: const DonationPayment(500),
          phone: '677123456',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('wraps network errors', () async {
      final dataSource = build((_) => throw http.ClientException('offline'));

      expect(
        () => dataSource.initiate(
          purpose: const DonationPayment(500),
          phone: '677123456',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('status', () {
    test('GETs the status for the transaction', () async {
      final dataSource = build(
        (_) => http.Response(jsonEncode({'status': 'SUCCESSFUL'}), 200),
      );

      expect(await dataSource.status('KGEartB8BK'), 'SUCCESSFUL');
      final request = requests.single;
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://rust.example.com/payments/status/KGEartB8BK',
      );
      expect(request.headers['Authorization'], 'Bearer access-token');
    });

    test('encodes the transaction id into a single path segment', () async {
      final dataSource = build(
        (_) => http.Response(jsonEncode({'status': 'CREATED'}), 200),
      );

      await dataSource.status('a/../b');

      expect(requests.single.url.pathSegments, [
        'payments',
        'status',
        'a/../b',
      ]);
    });

    test('surfaces a 404 as a server error', () async {
      final dataSource = build(
        (_) => http.Response(jsonEncode({'error': 'Payment x not found'}), 404),
      );

      expect(() => dataSource.status('x'), throwsA(isA<ServerException>()));
    });
  });
}
