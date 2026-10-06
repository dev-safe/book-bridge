import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/network/rust_core_client.dart';
import 'package:book_bridge/features/admin/data/datasources/rust_admin_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _txId = '11111111-2222-4333-8444-555555555555';
const _logId = '99999999-2222-4333-8444-555555555555';

void main() {
  late List<http.Request> requests;

  RustAdminDataSource build(http.Response Function(http.Request) respond) {
    requests = [];
    return RustAdminDataSource(
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

  // Axum sends UTF-8 JSON without a charset parameter.
  http.Response ok(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json'},
  );

  group('checkAdmin', () {
    test('passes for admins', () async {
      final ds = build((_) => ok({'admin': true}));

      await ds.checkAdmin();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/admin/me');
    });

    test('throws the server message for non-admins (403)', () async {
      final ds = build(
        (_) =>
            http.Response(jsonEncode({'error': 'Admin access required'}), 403),
      );

      await expectLater(
        ds.checkAdmin(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Admin access required'),
          ),
        ),
      );
    });

    test('throws AuthAppException when signed out (401)', () async {
      final ds = build(
        (_) => http.Response(jsonEncode({'error': 'Unauthorized'}), 401),
      );

      await expectLater(ds.checkAdmin(), throwsA(isA<AuthAppException>()));
    });
  });

  test('disputes parses the list', () async {
    final ds = build(
      (_) => ok({
        'disputes': [
          {
            'transaction_id': _txId,
            'amount': 500,
            'listing_title': 'Physics F5',
            'buyer_name': 'Élodie',
            'seller_name': 'Ben',
            'dispute_reason': 'Not received',
            'purchased_at': '2026-09-30T01:00:00Z',
            'disputed_at': '2026-09-30T02:00:00Z',
            'payer_phone_hint': '677•••456',
          },
          {'transaction_id': _txId, 'amount': 100},
        ],
      }),
    );

    final disputes = await ds.disputes();

    expect(requests.single.url.path, '/admin/disputes');
    expect(disputes, hasLength(2));
    expect(disputes.first.transactionId, _txId);
    expect(disputes.first.amount, 500);
    expect(disputes.first.listingTitle, 'Physics F5');
    expect(disputes.first.buyerName, 'Élodie');
    expect(disputes.first.payerPhoneHint, '677•••456');
    expect(disputes.first.disputedAt, DateTime.utc(2026, 9, 30, 2).toLocal());
    expect(disputes.last.payerPhoneHint, isNull);
    expect(disputes.last.disputedAt, isNull);
  });

  test('disputes rejects a response without a list', () async {
    final ds = build((_) => ok({'items': []}));

    await expectLater(ds.disputes(), throwsA(isA<ServerException>()));
  });

  test('unmatchedPayments parses the list', () async {
    final ds = build(
      (_) => ok({
        'payments': [
          {
            'id': _logId,
            'trans_id': 'abc123',
            'amount': 1500.0,
            'external_id': null,
            'reason': 'No matching transaction',
            'received_at': '2026-09-30T02:00:00Z',
            'payer_phone_hint': null,
          },
        ],
      }),
    );

    final payments = await ds.unmatchedPayments();

    expect(requests.single.url.path, '/admin/unmatched-payments');
    expect(payments.single.id, _logId);
    expect(payments.single.transId, 'abc123');
    expect(payments.single.amount, 1500);
    expect(payments.single.payerPhoneHint, isNull);
  });

  group('actions POST the note, and the phone only when given', () {
    final cases =
        <
          String,
          (
            String path,
            Future<void> Function(RustAdminDataSource ds) run,
            Map<String, Object?> body,
          )
        >{
          'releaseDispute': (
            '/admin/disputes/$_txId/release',
            (ds) => ds.releaseDispute(_txId, 'Seller showed proof'),
            {'note': 'Seller showed proof'},
          ),
          'refundDispute with phone': (
            '/admin/disputes/$_txId/refund',
            (ds) => ds.refundDispute(_txId, 'Never sent', phone: '677123456'),
            {'note': 'Never sent', 'phone': '677123456'},
          ),
          'refundDispute without phone': (
            '/admin/disputes/$_txId/refund',
            (ds) => ds.refundDispute(_txId, 'Never sent'),
            {'note': 'Never sent'},
          ),
          'refundUnmatched': (
            '/admin/unmatched-payments/$_logId/refund',
            (ds) =>
                ds.refundUnmatched(_logId, 'Paid twice', phone: '690000000'),
            {'note': 'Paid twice', 'phone': '690000000'},
          ),
          'dismissUnmatched': (
            '/admin/unmatched-payments/$_logId/dismiss',
            (ds) => ds.dismissUnmatched(_logId, 'Refunded by hand'),
            {'note': 'Refunded by hand'},
          ),
        };

    cases.forEach((name, c) {
      test(name, () async {
        final ds = build(
          (_) => ok({'ok': true, 'payout_reference': 'payout-1'}),
        );

        await c.$2(ds);

        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, c.$1);
        expect(jsonDecode(request.body), c.$3);
      });
    });
  });

  group('ID verification', () {
    const userId = '77777777-2222-4333-8444-555555555555';

    test('idVerifications parses the list', () async {
      final ds = build(
        (_) => ok({
          'submissions': [
            {
              'user_id': userId,
              'full_name': 'Ngum Awa',
              'date_of_birth': '2013-05-01',
              'age': 12,
              'id_type': 'school_id',
              'guardian_phone_hint': '677•••456',
              'document_paths': ['$userId/id.jpg', '$userId/guardian.jpg', 7],
              'submitted_at': '2026-10-01T08:00:00Z',
            },
            {'user_id': userId},
          ],
        }),
      );

      final submissions = await ds.idVerifications();

      expect(requests.single.url.path, '/admin/id-verifications');
      expect(submissions, hasLength(2));
      final first = submissions.first;
      expect(first.fullName, 'Ngum Awa');
      expect(first.age, 12);
      expect(first.idType, 'school_id');
      expect(first.guardianPhoneHint, '677•••456');
      expect(first.documentPaths, ['$userId/id.jpg', '$userId/guardian.jpg']);
      expect(first.dateOfBirth?.year, 2013);
      expect(first.submittedAt, DateTime.utc(2026, 10, 1, 8).toLocal());
      expect(submissions.last.documentPaths, isEmpty);
      expect(submissions.last.age, isNull);
    });

    test('idVerifications rejects a submission without user_id', () async {
      final ds = build(
        (_) => ok({
          'submissions': [
            {'full_name': 'x'},
          ],
        }),
      );

      await expectLater(ds.idVerifications(), throwsA(isA<ServerException>()));
    });

    test('approveId and rejectId POST the note', () async {
      final ds = build((_) => ok({'ok': true}));

      await ds.approveId(userId, 'CNI matches');
      await ds.rejectId(userId, 'Blurry');

      expect(requests[0].url.path, '/admin/id-verifications/$userId/approve');
      expect(jsonDecode(requests[0].body), {'note': 'CNI matches'});
      expect(requests[1].url.path, '/admin/id-verifications/$userId/reject');
      expect(jsonDecode(requests[1].body), {'note': 'Blurry'});
    });

    test('idPhotoUrl uses the injected signer', () async {
      final ds = RustAdminDataSource(
        RustCoreClient(
          baseUrl: 'https://rust.example.com',
          accessToken: () async => 't',
          httpClient: MockClient((_) async => http.Response('', 500)),
        ),
        signIdPhoto: (path) async => 'signed:$path',
      );

      expect(await ds.idPhotoUrl('a/b.jpg'), 'signed:a/b.jpg');
    });

    test('idPhotoUrl throws without a signer', () async {
      final ds = build((_) => ok({}));

      await expectLater(
        ds.idPhotoUrl('a/b.jpg'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('content reports', () {
    const reportId = '33333333-2222-4333-8444-555555555555';

    test('reports parses the list', () async {
      final ds = build(
        (_) => ok({
          'reports': [
            {
              'id': reportId,
              'reason': 'scam',
              'details': 'Asked for payment upfront',
              'created_at': '2026-10-19T10:00:00Z',
              'reporter_name': 'Ama',
              'listing_id': 'listing-1',
              'listing_title': 'Physics F5',
              'listing_status': 'available',
              'reported_user_id': 'seller-1',
              'reported_user_name': 'Bob',
            },
          ],
        }),
      );

      final reports = await ds.reports();

      expect(requests.single.url.path, '/admin/reports');
      final report = reports.single;
      expect(report.id, reportId);
      expect(report.reason, 'scam');
      expect(report.isAboutListing, isTrue);
      expect(report.listingTitle, 'Physics F5');
      expect(report.reportedUserName, 'Bob');
      expect(report.createdAt, isNotNull);
    });

    test('reports rejects a report without an id', () async {
      final ds = build(
        (_) => ok({
          'reports': [
            {'reason': 'spam'},
          ],
        }),
      );

      await expectLater(ds.reports(), throwsA(isA<ServerException>()));
    });

    test('dismiss and remove-listing POST the note', () async {
      final ds = build((_) => ok({'ok': true}));

      await ds.dismissReport(reportId, 'Not a violation');
      await ds.removeReportedListing(reportId, 'Counterfeit');

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/admin/reports/$reportId/dismiss');
      expect(jsonDecode(requests[0].body), {'note': 'Not a violation'});
      expect(requests[1].url.path, '/admin/reports/$reportId/remove-listing');
      expect(jsonDecode(requests[1].body), {'note': 'Counterfeit'});
    });
  });

  test('a 409 from a second click surfaces the server message', () async {
    final ds = build(
      (_) => http.Response(
        jsonEncode({'error': 'A refund is already in progress'}),
        409,
      ),
    );

    await expectLater(
      ds.refundDispute(_txId, 'again'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('already in progress'),
        ),
      ),
    );
  });
}
