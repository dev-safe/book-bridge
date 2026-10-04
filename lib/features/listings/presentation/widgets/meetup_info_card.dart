import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds a maps search URL for a meetup pin.
Uri meetupMapsUri(double latitude, double longitude) => Uri.parse(
  'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
);

/// Shows the seller's meetup spot, with "Open in Maps" when a pin is set.
///
/// Renders nothing when there is no spot and no pin.
class MeetupInfoCard extends StatelessWidget {
  final String? spot;
  final double? latitude;
  final double? longitude;
  final bool showSafetyHint;

  const MeetupInfoCard({
    super.key,
    this.spot,
    this.latitude,
    this.longitude,
    this.showSafetyHint = true,
  });

  bool get _hasPin => latitude != null && longitude != null;

  Future<void> _openMaps(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = meetupMapsUri(latitude!, longitude!);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.meetupOpenMapsFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = spot?.trim();
    final hasSpot = trimmed != null && trimmed.isNotEmpty;
    if (!hasSpot && !_hasPin) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.meetupSpotLabel,
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      hasSpot ? trimmed : l10n.meetupPinOnly,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasPin)
                TextButton.icon(
                  onPressed: () => _openMaps(context),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.openInMaps),
                ),
            ],
          ),
          if (showSafetyHint) ...[
            const SizedBox(height: 8),
            Text(l10n.meetupSafetyHint, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
