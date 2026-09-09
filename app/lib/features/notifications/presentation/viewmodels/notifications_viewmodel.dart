import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/notifications/domain/entities/notification.dart';
import 'package:book_bridge/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsViewModel extends ChangeNotifier {
  final NotificationsRepository _repository;

  List<Notification> _notifications = [];
  StreamSubscription<List<Notification>>? _subscription;
  bool _isLoading = true;
  String? _errorMessage;

  List<Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationsViewModel(this._repository);

  void subscribeToNotifications() {
    _isLoading = true;
    notifyListeners();

    try {
      _subscription = _repository.getNotificationsStream().listen(
        (data) {
          _notifications = data;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          _isLoading = false;
          _errorMessage = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      // Don't show error if it's just auth (user might be logged out)
      if (e.toString().contains('User not authenticated')) {
        _notifications = [];
        _errorMessage = null;
      } else {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      // Optimistic update
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        // We can't modify the entity directly as it should be immutable (Equatable),
        // but the stream will update the list shortly.
        // For immediate feedback, we rely on the stream update which should be fast with Supabase.
      }
      await _repository.markAsRead(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
