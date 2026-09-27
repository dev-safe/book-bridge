import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/transactions/data/datasources/supabase_transactions_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

const _txId = '11111111-2222-4333-8444-555555555555';

void main() {
  late List<http.Request> requests;

  SupabaseTransactionsDataSource build({
    required http.Response Function(http.Request) respond,
    String? token = 'access-token',
    String url = 'https://rust.example.com/',
  }) {
    requests = [];
    return SupabaseTransactionsDataSource(
      supabaseClient: _MockSupabaseClient(),
      rustCoreUrl: url,
      httpClient: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
      accessToken: () async => token,
    );
  }

  http.Response ok() => http.Response(jsonEncode({'ok': true}), 200);

  group('confirmReceipt', () {
    test('POSTs the transaction id to Rust with the bearer token', () async {
      final dataSource = build(respond: (_) => ok());

      await dataSource.confirmReceipt(_txId);

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://rust.example.com/escrow/confirm-receipt',
      );
      expect(request.headers['Authorization'], 'Bearer access-token');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'transaction_id': _txId});
    });

    test('surfaces the server error message on 409', () async {
      final dataSource = build(
        respond: (_) => http.Response(
          jsonEncode({'error': "Transaction is 'released', not 'held'"}),
          409,
        ),
      );

      await expectLater(
        () => dataSource.confirmReceipt(_txId),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            "Failed to confirm receipt: Transaction is 'released', not 'held'",
          ),
        ),
      );
    });

    test('asks the user to sign in again on 401', () async {
      final dataSource = build(
        respond: (_) => http.Response(jsonEncode({'error': 'Invalid'}), 401),
      );

      await expectLater(
        () => dataSource.confirmReceipt(_txId),
        throwsA(isA<AuthAppException>()),
      );
    });

    test('does not call Rust when there is no session', () async {
      final dataSource = build(respond: (_) => ok(), token: null);

      await expectLater(
        () => dataSource.confirmReceipt(_txId),
        throwsA(isA<AuthAppException>()),
      );
      expect(requests, isEmpty);
    });

    test('falls back to the status code for non-JSON errors', () async {
      final dataSource = build(
        respond: (_) => http.Response('<html>Bad Gateway</html>', 502),
      );

      await expectLater(
        () => dataSource.confirmReceipt(_txId),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Failed to confirm receipt: Request failed (502)',
          ),
        ),
      );
    });

    test('wraps network errors in ServerException', () async {
      final dataSource = build(
        respond: (_) => throw http.ClientException('connection refused'),
      );

      await expectLater(
        () => dataSource.confirmReceipt(_txId),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('connection refused'),
          ),
        ),
      );
    });
  });

  group('disputeTransaction', () {
    test('POSTs the transaction id and reason to Rust', () async {
      final dataSource = build(
        respond: (_) => ok(),
        url: 'https://rust.example.com',
      );

      await dataSource.disputeTransaction(_txId, 'Book never arrived');

      final request = requests.single;
      expect(request.url.toString(), 'https://rust.example.com/escrow/dispute');
      expect(request.headers['Authorization'], 'Bearer access-token');
      expect(jsonDecode(request.body), {
        'transaction_id': _txId,
        'dispute_reason': 'Book never arrived',
      });
    });

    test('surfaces validation errors from Rust', () async {
      final dataSource = build(
        respond: (_) => http.Response(
          jsonEncode({'error': 'dispute_reason is required'}),
          400,
        ),
      );

      await expectLater(
        () => dataSource.disputeTransaction(_txId, '   '),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Failed to dispute transaction: dispute_reason is required',
          ),
        ),
      );
    });
  });
}
