import 'package:book_bridge/features/chat/domain/entities/message.dart';

/// Data Transfer Object for Message.
/// Maps Supabase database rows to the Message domain entity.
class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.listingId,
    required super.senderId,
    required super.receiverId,
    required super.content,
    required super.isRead,
    required super.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_read': isRead,
    };
  }
}
