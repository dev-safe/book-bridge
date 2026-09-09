import 'package:book_bridge/features/notifications/domain/entities/notification.dart';

abstract class NotificationsRepository {
  /// Stream of notifications for the current user.
  Stream<List<Notification>> getNotificationsStream();

  /// Marks a specific notification as read.
  Future<void> markAsRead(String id);

  /// Marks all notifications as read.
  Future<void> markAllAsRead();
}
