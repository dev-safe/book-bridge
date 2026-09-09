import 'package:book_bridge/core/error/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/features/notifications/data/models/notification_model.dart';

class SupabaseNotificationsDataSource {
  final SupabaseClient _supabaseClient;

  SupabaseNotificationsDataSource(this._supabaseClient);

  Stream<List<NotificationModel>> getNotificationsStream() {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw AuthAppException(message: 'User not authenticated');
      }

      return _supabaseClient
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at')
          .map(
            (data) =>
                data.map((json) => NotificationModel.fromJson(json)).toList(),
          );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return;

      await _supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
