import 'package:book_bridge/core/utils/geo_radius.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Formats a radius such as 1.0 or 2.5 without a trailing ".0".
String formatRadiusKm(double km) =>
    km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toString();

/// Horizontal chip row to pick a distance radius ("Any" or a preset).
class RadiusFilterBar extends StatelessWidget {
  final double? selectedKm;
  final ValueChanged<double?> onChanged;
  final VoidCallback? onOpenMap;

  const RadiusFilterBar({
    super.key,
    required this.selectedKm,
    required this.onChanged,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _RadiusChip(
            label: l10n.radiusAny,
            selected: selectedKm == null,
            onTap: () => onChanged(null),
          ),
          for (final km in kRadiusPresetsKm)
            _RadiusChip(
              label: l10n.withinKm(formatRadiusKm(km)),
              selected: selectedKm == km,
              onTap: () => onChanged(km),
            ),
          if (onOpenMap != null)
            ActionChip(
              avatar: const Icon(Icons.map_outlined, size: 18),
              label: Text(l10n.showOnMap),
              onPressed: onOpenMap,
            ),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
