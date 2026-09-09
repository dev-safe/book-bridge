import 'package:equatable/equatable.dart';

/// Represents a single chat message between a buyer and seller.
class Message extends Equatable {
  final String id;
  final String listingId;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.listingId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    listingId,
    senderId,
    receiverId,
    content,
    isRead,
    createdAt,
  ];
}
