import 'package:equatable/equatable.dart';

class Notification extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type; // 'general', 'listing', 'message', 'security'
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  @override
  List<Object?> get props => [id, title, body, type, isRead, createdAt, data];
}
