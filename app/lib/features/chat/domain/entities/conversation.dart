import 'package:equatable/equatable.dart';

/// Represents a conversation summary (last message per listing+participant pair).
class Conversation extends Equatable {
  final String listingId;
  final String listingTitle;
  final String? listingImageUrl;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  const Conversation({
    required this.listingId,
    required this.listingTitle,
    this.listingImageUrl,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [
    listingId,
    otherUserId,
    lastMessage,
    lastMessageAt,
    unreadCount,
  ];
}
