import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/data/datasources/supabase_moderation_data_source.dart';
import 'package:book_bridge/features/moderation/domain/entities/moderation_failure.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

typedef SubmitReport =
    Future<Failure?> Function(ReportReason reason, String? details);

/// Asks for a reason and optional details, then calls [onSubmit]. Returns
/// true once the report was sent.
Future<bool> showReportSheet(
  BuildContext context, {
  required String title,
  required SubmitReport onSubmit,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportSheet(title: title, onSubmit: onSubmit),
  );
  return sent ?? false;
}

String reportReasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.scam => l10n.reportReasonScam,
      ReportReason.inappropriate => l10n.reportReasonInappropriate,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.prohibited => l10n.reportReasonProhibited,
      ReportReason.other => l10n.reportReasonOther,
    };

class ReportSheet extends StatefulWidget {
  final String title;
  final SubmitReport onSubmit;

  const ReportSheet({super.key, required this.title, required this.onSubmit});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await widget.onSubmit(reason, _details.text);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error =
          failure is ModerationFailure &&
              failure.kind == ModerationFailureKind.reportLimit
          ? l10n.reportLimitReached
          : l10n.moderationFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.reportTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) {
                  if (!_sending) setState(() => _reason = value);
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        title: Text(reportReasonLabel(l10n, reason)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_sending,
                maxLength: SupabaseModerationDataSource.maxDetailsLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.reportDetailsHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _reason == null || _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.reportSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
