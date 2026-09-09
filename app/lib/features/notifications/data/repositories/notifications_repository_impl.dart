import 'package:book_bridge/features/notifications/data/datasources/supabase_notifications_data_source.dart';
import 'package:book_bridge/features/notifications/domain/entities/notification.dart';
import 'package:book_bridge/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final SupabaseNotificationsDataSource _dataSource;

  NotificationsRepositoryImpl(this._dataSource);

  @override
  Stream<List<Notification>> getNotificationsStream() {
    return _dataSource.getNotificationsStream();
  }

  @override
  Future<void> markAsRead(String id) async {
    await _dataSource.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() async {
    await _dataSource.markAllAsRead();
  }
}
