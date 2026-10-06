import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the server refuses a report because the daily limit was hit.
class ReportLimitException extends ServerException {
  ReportLimitException({required super.message});
}

/// `user_blocks` and `content_reports` through PostgREST; RLS limits both
/// to the signed-in user's own rows.
class SupabaseModerationDataSource {
  static const int maxDetailsLength = 500;
  static const String _uniqueViolation = '23505';

  final SupabaseClient supabaseClient;

  SupabaseModerationDataSource({required this.supabaseClient});

  String get _userId {
    final user = supabaseClient.auth.currentUser;
    if (user == null) throw AuthAppException(message: 'Not signed in');
    return user.id;
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final rows = await supabaseClient
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', _userId)
          .order('created_at', ascending: false);
      final ids = [for (final row in rows) row['blocked_id'] as String];
      if (ids.isEmpty) return const [];

      final profiles = await supabaseClient
          .from('public_profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', ids);
      final byId = {for (final p in profiles) p['id'] as String: p};
      return [
        for (final id in ids)
          BlockedUser(
            id: id,
            name: byId[id]?['full_name'] as String?,
            avatarUrl: byId[id]?['avatar_url'] as String?,
          ),
      ];
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await supabaseClient.from('user_blocks').insert({
        'blocker_id': _userId,
        'blocked_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return;
      throw ServerException(message: e.message);
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await supabaseClient
          .from('user_blocks')
          .delete()
          .eq('blocker_id', _userId)
          .eq('blocked_id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// Files a report about a listing or a user. The server sets the reporter
  /// from the session; the client cannot read reports back.
  Future<void> report({
    String? listingId,
    String? reportedUserId,
    required ReportReason reason,
    String? details,
  }) async {
    assert(listingId != null || reportedUserId != null);
    _userId; // Fails fast when signed out.
    final text = details?.trim() ?? '';
    try {
      await supabaseClient.from('content_reports').insert({
        'listing_id': ?listingId,
        'reported_user_id': ?reportedUserId,
        'reason': reason.wire,
        if (text.isNotEmpty)
          'details': text.length > maxDetailsLength
              ? text.substring(0, maxDetailsLength)
              : text,
      });
    } on PostgrestException catch (e) {
      // Already reported and still open: nothing more to do.
      if (e.code == _uniqueViolation) return;
      if (e.message.contains('report_limit')) {
        throw ReportLimitException(message: e.message);
      }
      throw ServerException(message: e.message);
    }
  }
}
