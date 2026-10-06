import 'package:book_bridge/features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/presentation/viewmodels/moderation_viewmodel.dart';
import 'package:book_bridge/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Report and block flows shared by the listing, chat and blocked-users
/// screens. Each shows its own confirmation and result messages.
class ModerationActions {
  const ModerationActions._();

  static Future<void> reportListing(
    BuildContext context,
    String listingId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final moderation = context.read<ModerationViewModel>();
    final sent = await showReportSheet(
      context,
      title: l10n.reportListing,
      onSubmit: (reason, details) =>
          moderation.reportListing(listingId, reason, details: details),
    );
    if (sent && context.mounted) _snack(context, l10n.reportSent);
  }

  static Future<void> reportUser(
    BuildContext context,
    String userId, {
    required String title,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final moderation = context.read<ModerationViewModel>();
    final sent = await showReportSheet(
      context,
      title: title,
      onSubmit: (reason, details) =>
          moderation.reportUser(userId, reason, details: details),
    );
    if (sent && context.mounted) _snack(context, l10n.reportSent);
  }

  /// Asks for confirmation, then blocks [user]. Returns true once blocked.
  static Future<bool> block(BuildContext context, BlockedUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final name = displayName(l10n, user.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.blockConfirmTitle(name)),
        content: Text(l10n.blockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.blockConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final failure = await context.read<ModerationViewModel>().block(user);
    if (!context.mounted) return failure == null;
    if (failure != null) {
      _snack(context, l10n.moderationFailed);
      return false;
    }
    _snack(context, l10n.userBlocked(name));
    _refreshFeeds(context);
    return true;
  }

  static Future<bool> unblock(BuildContext context, BlockedUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final failure = await context.read<ModerationViewModel>().unblock(user.id);
    if (!context.mounted) return failure == null;
    if (failure != null) {
      _snack(context, l10n.moderationFailed);
      return false;
    }
    _snack(context, l10n.userUnblocked(displayName(l10n, user.name)));
    _refreshFeeds(context);
    return true;
  }

  static String displayName(AppLocalizations l10n, String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? l10n.blockedUserFallbackName : trimmed;
  }

  static void _refreshFeeds(BuildContext context) {
    context.read<HomeViewModel>().refreshListings();
    context.read<ChatViewModel>().refreshConversationsSilently();
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
