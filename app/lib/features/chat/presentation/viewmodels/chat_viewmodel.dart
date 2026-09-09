import 'dart:async';
import 'package:flutter/material.dart';
import 'package:book_bridge/features/chat/domain/entities/conversation.dart';
import 'package:book_bridge/features/chat/domain/entities/message.dart';
import 'package:book_bridge/features/chat/domain/repositories/chat_repository.dart';

enum ChatState { idle, loading, success, error }

/// ViewModel for the in-app chat feature.
///
/// Manages messages stream, sending messages, and the conversations list.
class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repository;

  ChatViewModel({required ChatRepository repository})
    : _repository = repository;

  // ─── Conversations list state ────────────────────────────────────────────
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  ChatState _conversationsState = ChatState.idle;
  ChatState get conversationsState => _conversationsState;

  String? _conversationsError;
  String? get conversationsError => _conversationsError;

  /// Total number of unread messages across all conversations.
  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  // ─── Message thread state ─────────────────────────────────────────────────
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  ChatState _messagesState = ChatState.idle;
  ChatState get messagesState => _messagesState;

  StreamSubscription<List<Message>>? _messagesSub;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _sendError;
  String? get sendError => _sendError;

  // ─── Conversations ────────────────────────────────────────────────────────

  Future<void> loadConversations() async {
    _conversationsState = ChatState.loading;
    _conversationsError = null;
    notifyListeners();
    try {
      _conversations = await _repository.getConversations();
      _conversationsState = ChatState.success;
    } catch (e) {
      _conversationsError = e.toString();
      _conversationsState = ChatState.error;
    }
    notifyListeners();
  }

  /// Refresh conversations without switching to a loading state.
  /// Used by the navbar to poll the unread badge count silently.
  Future<void> refreshConversationsSilently() async {
    try {
      _conversations = await _repository.getConversations();
      notifyListeners();
    } catch (_) {}
  }

  // ─── Message Thread ───────────────────────────────────────────────────────

  void subscribeToMessages({
    required String listingId,
    required String otherUserId,
  }) {
    _messagesSub?.cancel();
    _messages = [];
    _messagesState = ChatState.loading;
    notifyListeners();

    _messagesSub = _repository
        .getMessages(listingId: listingId, otherUserId: otherUserId)
        .listen(
          (msgs) {
            _messages = msgs;
            _messagesState = ChatState.success;
            notifyListeners();
          },
          onError: (e) {
            _messagesState = ChatState.error;
            notifyListeners();
          },
        );

    // Mark incoming messages as read
    _repository.markMessagesAsRead(listingId: listingId, senderId: otherUserId);
  }

  void unsubscribeFromMessages() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _messages = [];
  }

  Future<void> sendMessage({
    required String listingId,
    required String receiverId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;
    _isSending = true;
    _sendError = null;
    notifyListeners();
    try {
      await _repository.sendMessage(
        listingId: listingId,
        receiverId: receiverId,
        content: content.trim(),
      );
    } catch (e) {
      _sendError = 'Failed to send message. Please try again.';
    }
    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}
