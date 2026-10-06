import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/chat/data/datasources/supabase_chat_data_source.dart';
import 'package:book_bridge/features/moderation/domain/blocked_users_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../../helpers/fake_supabase.dart';

void main() {
  late List<http.Request> requests;

  Map<String, Object?> message(String id, String otherUserId) => {
    'id': id,
    'listing_id': 'l1',
    'sender_id': otherUserId,
    'receiver_id': fakeUserId,
    'content': 'hi from $otherUserId',
    'is_read': false,
    'created_at': '2026-10-19T10:00:00Z',
    'listings': {'id': 'l1', 'title': 'Physics', 'image_url': null},
  };

  Future<SupabaseChatDataSource> build(
    http.Response Function(http.Request) respond, {
    BlockedUsersCache? blocked,
  }) async {
    requests = [];
    final client = await fakeSupabaseClient(
      recordingHttpClient(requests, respond),
    );
    return SupabaseChatDataSource(
      supabaseClient: client,
      blockedUsers: blocked,
    );
  }

  test('getConversations hides blocked users', () async {
    final blocked = BlockedUsersCache()..add('u3');
    final ds = await build((request) {
      final path = request.url.path;
      final select = request.url.queryParameters['select'] ?? '';
      if (path.endsWith('/public_profiles')) {
        return jsonResponse([
          {'id': 'u2', 'full_name': 'Bob', 'avatar_url': null},
        ]);
      }
      if (select.contains('listings')) {
        return jsonResponse([message('m1', 'u2'), message('m2', 'u3')]);
      }
      return jsonResponse([]);
    }, blocked: blocked);

    final conversations = await ds.getConversations();

    expect(conversations.map((c) => c.otherUserId), ['u2']);
    final profiles = requests.firstWhere(
      (r) => r.url.path.endsWith('/public_profiles'),
    );
    expect(profiles.url.queryParameters['id'], 'in.("u2")');
  });

  group('sendMessage', () {
    test('maps the block trigger to MessagingBlockedException', () async {
      final ds = await build(
        (_) => jsonResponse({
          'code': 'P0001',
          'message': 'blocked: messages between these users are blocked',
        }, 400),
      );

      await expectLater(
        ds.sendMessage(listingId: 'l1', receiverId: 'u2', content: 'hi'),
        throwsA(isA<MessagingBlockedException>()),
      );
    });

    test('other failures stay ServerException', () async {
      final ds = await build(
        (_) => jsonResponse({'code': '42501', 'message': 'denied'}, 403),
      );

      await expectLater(
        ds.sendMessage(listingId: 'l1', receiverId: 'u2', content: 'hi'),
        throwsA(
          isA<ServerException>().having(
            (e) => e,
            'not blocked',
            isNot(isA<MessagingBlockedException>()),
          ),
        ),
      );
    });
  });
}
