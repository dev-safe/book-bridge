import 'package:book_bridge/features/chat/data/datasources/supabase_chat_data_source.dart';
import 'package:book_bridge/features/chat/domain/entities/conversation.dart';
import 'package:book_bridge/features/chat/domain/entities/message.dart';
import 'package:book_bridge/features/chat/domain/repositories/chat_repository.dart';

/// Concrete implementation of [ChatRepository] using Supabase.
class ChatRepositoryImpl implements ChatRepository {
  final SupabaseChatDataSource dataSource;

  ChatRepositoryImpl({required this.dataSource});

  @override
  Stream<List<Message>> getMessages({
    required String listingId,
    required String otherUserId,
  }) {
    return dataSource.getMessages(
      listingId: listingId,
      otherUserId: otherUserId,
    );
  }

  @override
  Future<void> sendMessage({
    required String listingId,
    required String receiverId,
    required String content,
  }) async {
    await dataSource.sendMessage(
      listingId: listingId,
      receiverId: receiverId,
      content: content,
    );
  }

  @override
  Future<void> markMessagesAsRead({
    required String listingId,
    required String senderId,
  }) async {
    await dataSource.markMessagesAsRead(
      listingId: listingId,
      senderId: senderId,
    );
  }

  @override
  Future<List<Conversation>> getConversations() async {
    return dataSource.getConversations();
  }
}
