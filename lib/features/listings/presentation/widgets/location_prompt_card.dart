import 'package:book_bridge/core/location/location_access.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Home banner that explains why nearby books are missing and offers the
/// one action that fixes it (turn on GPS, allow, or open app settings).
class LocationPromptCard extends StatelessWidget {
  const LocationPromptCard({
    super.key,
    required this.status,
    required this.onAction,
    required this.onDismiss,
  });

  final LocationAccessStatus status;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (message, actionLabel) = switch (status) {
      LocationAccessStatus.serviceDisabled => (
        l10n.locationServiceOffMessage,
        l10n.locationTurnOn,
      ),
      LocationAccessStatus.deniedForever => (
        l10n.locationPermissionBlockedMessage,
        l10n.locationOpenSettings,
      ),
      _ => (l10n.locationPermissionDeniedMessage, l10n.locationAllow),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: const Icon(Icons.location_on_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.locationPromptTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: onDismiss,
                      child: Text(l10n.locationNotNow),
                    ),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
