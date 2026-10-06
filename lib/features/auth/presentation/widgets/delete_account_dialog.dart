import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Asks the user to confirm, then deletes their account.
///
/// [deleteAccount] performs the server-side deletion; [onDeleted] runs once
/// it succeeds (normally a sign-out, which sends the user to sign-in).
Future<void> confirmAndDeleteAccount(
  BuildContext context, {
  required Future<void> Function() deleteAccount,
  required Future<void> Function() onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ConfirmDeleteDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.deleteAccountInProgress)),
          ],
        ),
      ),
    ),
  );

  Object? error;
  try {
    await deleteAccount();
  } catch (e) {
    error = e;
  }
  navigator.pop();

  if (error == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountSuccess)));
    await onDeleted();
    return;
  }
  if (error is ConflictException) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountActiveOrdersTitle),
        content: Text(l10n.deleteAccountActiveOrders),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountError)));
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog();

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final danger = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountMessage),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text(l10n.deleteAccountConfirmCheckbox),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: danger),
          child: Text(l10n.deleteAccount),
        ),
      ],
    );
  }
}
