import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/presentation/viewmodels/moderation_viewmodel.dart';
import 'package:book_bridge/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _MenuAction { reportListing, reportUser, block, unblock }

/// Overflow menu to report a listing or user, and block or unblock them.
class ModerationMenu extends StatelessWidget {
  /// The listing being viewed, if any; adds "Report listing".
  final String? listingId;
  final BlockedUser user;

  /// True when [user] is the seller of [listingId].
  final bool isSeller;
  final Color? iconColor;

  /// Called after [user] is blocked.
  final VoidCallback? onBlocked;

  const ModerationMenu({
    super.key,
    required this.user,
    this.listingId,
    this.isSeller = false,
    this.iconColor,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBlocked = context.select<ModerationViewModel, bool>(
      (vm) => vm.isBlocked(user.id),
    );
    final reportUserLabel = isSeller ? l10n.reportSeller : l10n.reportUser;
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.moreOptions,
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (action) async {
        switch (action) {
          case _MenuAction.reportListing:
            await ModerationActions.reportListing(context, listingId!);
          case _MenuAction.reportUser:
            await ModerationActions.reportUser(
              context,
              user.id,
              title: reportUserLabel,
            );
          case _MenuAction.block:
            final blocked = await ModerationActions.block(context, user);
            if (blocked) onBlocked?.call();
          case _MenuAction.unblock:
            await ModerationActions.unblock(context, user);
        }
      },
      itemBuilder: (_) => [
        if (listingId != null)
          PopupMenuItem(
            value: _MenuAction.reportListing,
            child: _item(Icons.flag_outlined, l10n.reportListing),
          ),
        PopupMenuItem(
          value: _MenuAction.reportUser,
          child: _item(Icons.person_off_outlined, reportUserLabel),
        ),
        isBlocked
            ? PopupMenuItem(
                value: _MenuAction.unblock,
                child: _item(Icons.lock_open_outlined, l10n.unblockUser),
              )
            : PopupMenuItem(
                value: _MenuAction.block,
                child: _item(Icons.block, l10n.blockUser),
              ),
      ],
    );
  }

  Widget _item(IconData icon, String label) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
  );
}
