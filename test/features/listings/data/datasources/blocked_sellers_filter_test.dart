import 'package:book_bridge/features/listings/data/datasources/supabase_listings_data_source.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:book_bridge/features/moderation/domain/blocked_users_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../../helpers/fake_supabase.dart';

void main() {
  late List<http.Request> requests;
  late BlockedUsersCache blocked;
  late SupabaseListingsDataSource dataSource;

  setUp(() async {
    requests = [];
    blocked = BlockedUsersCache();
    final client = await fakeSupabaseClient(
      recordingHttpClient(requests, (_) => jsonResponse([])),
    );
    dataSource = SupabaseListingsDataSource(
      supabaseClient: client,
      storageDataSource: SupabaseStorageDataSource(supabaseClient: client),
      blockedUsers: blocked,
    );
  });

  group('getListings', () {
    test('does not filter sellers when nobody is blocked', () async {
      await dataSource.getListings();

      expect(requests.single.url.queryParameters, isNot(contains('seller_id')));
    });

    test('hides blocked sellers', () async {
      blocked.replaceAll(['u2', 'u3']);

      await dataSource.getListings();

      expect(
        requests.single.url.queryParameters['seller_id'],
        'not.in.("u2","u3")',
      );
    });
  });

  group('searchListings', () {
    test('keeps the caller limit when nothing is filtered', () async {
      await dataSource.searchListings('physics', limit: 20);

      final request = requests.single;
      expect(request.url.queryParameters, isNot(contains('seller_id')));
      expect(request.body, contains('"_limit":20'));
    });

    test('hides blocked sellers and widens the search window', () async {
      blocked.add('u2');

      await dataSource.searchListings('physics', limit: 20);

      final request = requests.single;
      expect(request.url.queryParameters['seller_id'], 'not.in.("u2")');
      expect(request.body, contains('"_limit":500'));
      expect(request.url.queryParameters['limit'], '20');
    });
  });

  test("a seller's own page is never filtered", () async {
    blocked.add('u2');

    await dataSource.getListingsBySeller('u2');

    expect(requests.single.url.queryParameters['seller_id'], 'eq.u2');
  });
}
