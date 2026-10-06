import 'dart:convert';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/moderation/data/datasources/supabase_moderation_data_source.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/fake_supabase.dart';

void main() {
  late List<http.Request> requests;

  Future<SupabaseModerationDataSource> build(
    http.Response Function(http.Request) respond, {
    bool signedIn = true,
  }) async {
    requests = [];
    final client = await fakeSupabaseClient(
      recordingHttpClient(requests, respond),
      signedIn: signedIn,
    );
    return SupabaseModerationDataSource(supabaseClient: client);
  }

  const json = jsonResponse;

  http.Response pgError(String code, String message) =>
      json({'code': code, 'message': message}, 400);

  group('getBlockedUsers', () {
    test('loads blocks then their public profiles', () async {
      final ds = await build((request) {
        if (request.url.path.endsWith('/user_blocks')) {
          return json([
            {'blocked_id': 'u2'},
            {'blocked_id': 'u3'},
          ]);
        }
        return json([
          {'id': 'u3', 'full_name': 'Carol', 'avatar_url': null},
          {'id': 'u2', 'full_name': 'Bob', 'avatar_url': 'https://a/b.png'},
        ]);
      });

      final users = await ds.getBlockedUsers();

      expect(users.map((u) => u.id), ['u2', 'u3']);
      expect(users.first.name, 'Bob');
      expect(users.first.avatarUrl, 'https://a/b.png');
      expect(requests[0].url.queryParameters['blocker_id'], 'eq.$fakeUserId');
      expect(requests[1].url.path, endsWith('/public_profiles'));
      expect(requests[1].url.queryParameters['id'], 'in.("u2","u3")');
    });

    test('skips the profile lookup when nobody is blocked', () async {
      final ds = await build((_) => json([]));

      expect(await ds.getBlockedUsers(), isEmpty);
      expect(requests, hasLength(1));
    });

    test('throws when signed out', () async {
      final ds = await build((_) => json([]), signedIn: false);

      await expectLater(ds.getBlockedUsers(), throwsA(isA<AuthAppException>()));
      expect(requests, isEmpty);
    });
  });

  group('blockUser', () {
    test('inserts a block for the current user', () async {
      final ds = await build((_) => http.Response('', 201));

      await ds.blockUser('u2');

      expect(requests.single.method, 'POST');
      expect(jsonDecode(requests.single.body), {
        'blocker_id': fakeUserId,
        'blocked_id': 'u2',
      });
    });

    test('treats an existing block as success', () async {
      final ds = await build((_) => pgError('23505', 'duplicate key'));

      await ds.blockUser('u2');
    });

    test('surfaces other errors', () async {
      final ds = await build((_) => pgError('42501', 'permission denied'));

      await expectLater(ds.blockUser('u2'), throwsA(isA<ServerException>()));
    });
  });

  test('unblockUser deletes only the current user\'s block', () async {
    final ds = await build((_) => http.Response('', 204));

    await ds.unblockUser('u2');

    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.queryParameters['blocker_id'], 'eq.$fakeUserId');
    expect(request.url.queryParameters['blocked_id'], 'eq.u2');
  });

  group('report', () {
    test('sends only the listing for a listing report', () async {
      final ds = await build((_) => http.Response('', 201));

      await ds.report(
        listingId: 'l1',
        reason: ReportReason.scam,
        details: '  Asked for money first  ',
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/content_reports'));
      // The client has no SELECT on reports, so it must not ask for rows.
      expect(request.headers['Prefer'] ?? '', isNot(contains('return=rep')));
      expect(jsonDecode(request.body), {
        'listing_id': 'l1',
        'reason': 'scam',
        'details': 'Asked for money first',
      });
    });

    test('omits empty details and caps long ones', () async {
      final ds = await build((_) => http.Response('', 201));

      await ds.report(reportedUserId: 'u2', reason: ReportReason.other);
      await ds.report(
        reportedUserId: 'u2',
        reason: ReportReason.harassment,
        details: 'x' * 600,
      );

      expect(jsonDecode(requests[0].body), {
        'reported_user_id': 'u2',
        'reason': 'other',
      });
      expect(
        (jsonDecode(requests[1].body)['details'] as String).length,
        SupabaseModerationDataSource.maxDetailsLength,
      );
    });

    test('treats a duplicate open report as success', () async {
      final ds = await build((_) => pgError('23505', 'duplicate key'));

      await ds.report(listingId: 'l1', reason: ReportReason.spam);
    });

    test('maps the daily limit to ReportLimitException', () async {
      final ds = await build(
        (_) => pgError('P0001', 'report_limit: too many reports today'),
      );

      await expectLater(
        ds.report(listingId: 'l1', reason: ReportReason.spam),
        throwsA(isA<ReportLimitException>()),
      );
    });
  });

  test('ReportReason wire values match the database check', () {
    expect(ReportReason.values.map((r) => r.wire), [
      'spam',
      'scam',
      'inappropriate',
      'harassment',
      'prohibited',
      'other',
    ]);
  });
}
