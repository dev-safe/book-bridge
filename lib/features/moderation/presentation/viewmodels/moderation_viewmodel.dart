import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/domain/blocked_users_cache.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:book_bridge/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:flutter/foundation.dart';

/// The signed-in user's blocks, plus report and block actions. Keeps
/// [BlockedUsersCache] in step so listings and chats hide blocked users.
class ModerationViewModel extends ChangeNotifier {
  final ModerationRepository _repository;
  final BlockedUsersCache _cache;

  ModerationViewModel({
    required ModerationRepository repository,
    required BlockedUsersCache cache,
  }) : _repository = repository,
       _cache = cache;

  List<BlockedUser> _blockedUsers = const [];
  String? _userId;
  bool _isLoading = false;
  Failure? _loadFailure;

  List<BlockedUser> get blockedUsers => _blockedUsers;
  bool get isLoading => _isLoading;
  Failure? get loadFailure => _loadFailure;

  bool isBlocked(String userId) => _cache.contains(userId);

  /// Loads [userId]'s blocks, or clears them when signed out. Returns true
  /// when the set of blocked users changed, so callers can refresh lists.
  Future<bool> load(String? userId) async {
    if (userId == null || userId.isEmpty) {
      final hadBlocks = !_cache.isEmpty;
      _userId = null;
      _setBlocked(const []);
      return hadBlocks;
    }
    if (userId != _userId) {
      // Never apply another account's blocks, even briefly.
      _userId = userId;
      _setBlocked(const []);
    }
    final before = _cache.ids;
    _isLoading = true;
    _loadFailure = null;
    notifyListeners();
    final result = await _repository.getBlockedUsers();
    _isLoading = false;
    if (_userId != userId) return false;
    result.fold((failure) => _loadFailure = failure, _setBlocked);
    notifyListeners();
    return !setEquals(before, _cache.ids);
  }

  /// Forgets the current user's blocks without notifying listeners, for use
  /// while the widget tree is being torn down on sign-out.
  void reset() {
    _userId = null;
    _isLoading = false;
    _loadFailure = null;
    _setBlocked(const []);
  }

  /// Returns null on success or the failure to show.
  Future<Failure?> block(BlockedUser user) async {
    final result = await _repository.blockUser(user.id);
    return result.fold((failure) => failure, (_) {
      if (!isBlocked(user.id)) _setBlocked([user, ..._blockedUsers]);
      notifyListeners();
      return null;
    });
  }

  Future<Failure?> unblock(String userId) async {
    final result = await _repository.unblockUser(userId);
    return result.fold((failure) => failure, (_) {
      _setBlocked(_blockedUsers.where((u) => u.id != userId).toList());
      notifyListeners();
      return null;
    });
  }

  Future<Failure?> reportListing(
    String listingId,
    ReportReason reason, {
    String? details,
  }) async {
    final result = await _repository.reportListing(
      listingId,
      reason,
      details: details,
    );
    return result.fold((failure) => failure, (_) => null);
  }

  Future<Failure?> reportUser(
    String userId,
    ReportReason reason, {
    String? details,
  }) async {
    final result = await _repository.reportUser(
      userId,
      reason,
      details: details,
    );
    return result.fold((failure) => failure, (_) => null);
  }

  void _setBlocked(List<BlockedUser> users) {
    _blockedUsers = List.unmodifiable(users);
    _cache.replaceAll(users.map((u) => u.id));
  }
}
