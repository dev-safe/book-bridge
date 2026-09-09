import 'package:book_bridge/features/chat/domain/entities/conversation.dart';
import 'package:book_bridge/features/chat/domain/entities/message.dart';

/// Abstract repository for chat operations.
abstract class ChatRepository {
  /// Returns a real-time stream of messages for a specific listing conversation.
  Stream<List<Message>> getMessages({
    required String listingId,
    required String otherUserId,
  });

  /// Sends a message in a listing conversation.
  Future<void> sendMessage({
    required String listingId,
    required String receiverId,
    required String content,
  });

  /// Marks all unread messages in a conversation as read.
  Future<void> markMessagesAsRead({
    required String listingId,
    required String senderId,
  });

  /// Returns all active conversations for the current user.
  Future<List<Conversation>> getConversations();
}
