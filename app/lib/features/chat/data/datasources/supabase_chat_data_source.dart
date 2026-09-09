import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/chat/data/models/message_model.dart';
import 'package:book_bridge/features/chat/domain/entities/conversation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data source for chat operations using Supabase.
///
/// Handles real-time message streams and CRUD operations
/// on the `messages` table.
class SupabaseChatDataSource {
  final SupabaseClient supabaseClient;

  SupabaseChatDataSource({required this.supabaseClient});

  String get _currentUserId => supabaseClient.auth.currentUser!.id;

  /// Returns a real-time stream of messages for a specific conversation
  /// (identified by listing_id + the two participant IDs).
  Stream<List<MessageModel>> getMessages({
    required String listingId,
    required String otherUserId,
  }) {
    return supabaseClient
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    row['listing_id'] == listingId &&
                    ((row['sender_id'] == _currentUserId &&
                            row['receiver_id'] == otherUserId) ||
                        (row['sender_id'] == otherUserId &&
                            row['receiver_id'] == _currentUserId)),
              )
              .map((row) => MessageModel.fromJson(row))
              .toList(),
        );
  }

  /// Sends a new message.
  Future<void> sendMessage({
    required String listingId,
    required String receiverId,
    required String content,
  }) async {
    try {
      await supabaseClient.from('messages').insert({
        'listing_id': listingId,
        'sender_id': _currentUserId,
        'receiver_id': receiverId,
        'content': content,
        'is_read': false,
      });
    } catch (e) {
      throw ServerException(message: 'Failed to send message: $e');
    }
  }

  /// Marks all unread messages from a given sender as read.
  Future<void> markMessagesAsRead({
    required String listingId,
    required String senderId,
  }) async {
    try {
      await supabaseClient
          .from('messages')
          .update({'is_read': true})
          .eq('listing_id', listingId)
          .eq('sender_id', senderId)
          .eq('receiver_id', _currentUserId)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(message: 'Failed to mark messages as read: $e');
    }
  }

  /// Fetches all conversations for the current user by querying messages,
  /// then grouping by listing_id + other participant.
  Future<List<Conversation>> getConversations() async {
    try {
      // Fetch all messages involving the current user
      final data = await supabaseClient
          .from('messages')
          .select('''
            id,
            listing_id,
            sender_id,
            receiver_id,
            content,
            is_read,
            created_at,
            listings!inner(
              id, title, image_url
            )
          ''')
          .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
          .order('created_at', ascending: false);

      // Group into conversations: one entry per (listing_id + other_user)
      final Map<String, Map<String, dynamic>> convMap = {};
      for (final row in data as List<dynamic>) {
        final otherUserId = row['sender_id'] == _currentUserId
            ? row['receiver_id'] as String
            : row['sender_id'] as String;
        final key = '${row['listing_id']}_$otherUserId';
        if (!convMap.containsKey(key)) {
          convMap[key] = {
            ...row as Map<String, dynamic>,
            'other_user_id': otherUserId,
          };
        }
      }

      // Fetch profile info for all other users in one batch
      final otherUserIds = convMap.values
          .map((c) => c['other_user_id'] as String)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (otherUserIds.isNotEmpty) {
        final profiles = await supabaseClient
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', otherUserIds);

        for (final p in profiles as List<dynamic>) {
          profileMap[p['id'] as String] = p as Map<String, dynamic>;
        }
      }

      // Count unread messages for each conversation
      final unread = await supabaseClient
          .from('messages')
          .select('listing_id, sender_id')
          .eq('receiver_id', _currentUserId)
          .eq('is_read', false);

      final Map<String, int> unreadCounts = {};
      for (final row in unread as List<dynamic>) {
        final key = '${row['listing_id']}_${row['sender_id']}';
        unreadCounts[key] = (unreadCounts[key] ?? 0) + 1;
      }

      return convMap.values.map((row) {
        final otherUserId = row['other_user_id'] as String;
        final profile = profileMap[otherUserId];
        final listing = row['listings'] as Map<String, dynamic>? ?? {};
        final key = '${row['listing_id']}_$otherUserId';

        return Conversation(
          listingId: row['listing_id'] as String,
          listingTitle: listing['title'] as String? ?? 'Unknown Listing',
          listingImageUrl: listing['image_url'] as String?,
          otherUserId: otherUserId,
          otherUserName: profile?['full_name'] as String? ?? 'Unknown User',
          otherUserAvatarUrl: profile?['avatar_url'] as String?,
          lastMessage: row['content'] as String,
          lastMessageAt: DateTime.parse(row['created_at'] as String),
          unreadCount: unreadCounts[key] ?? 0,
        );
      }).toList()..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    } catch (e) {
      throw ServerException(message: 'Failed to load conversations: $e');
    }
  }
}
