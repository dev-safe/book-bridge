import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';
import 'package:book_bridge/features/impact/presentation/widgets/count_up_text.dart';

class ImpactStatsWidget extends StatelessWidget {
  final PlatformStats stats;

  const ImpactStatsWidget({super.key, required this.stats});

  String _formatMoney(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}K';
    }
    return val.toStringAsFixed(0);
  }

  String _formatCo2(double valKg) {
    final tonnes = valKg / 1000.0;
    return tonnes.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Use localization keys if defined, fallback gracefully to hardcoded defaults
    final title = l10n.socialImpactTitle;
    final circulatedLabel = l10n.booksCirculated;
    final moneySavedLabel = l10n.moneySaved;
    final co2SavedLabel = l10n.co2Saved;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainer,
            theme.colorScheme.surfaceContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: '📚',
                  label: circulatedLabel,
                  value: stats.totalBooksCirculated,
                  formatter: (v) => v.toStringAsFixed(0),
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: '💰',
                  label: moneySavedLabel,
                  value: stats.totalMoneySavedFcfa,
                  formatter: (v) => _formatMoney(v),
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: '🌱',
                  label: co2SavedLabel,
                  value: stats.totalCo2AvoidedKg,
                  formatter: (v) => '${_formatCo2(v)}t',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String icon,
    required String label,
    required num value,
    required String Function(double) formatter,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$icon ', style: const TextStyle(fontSize: 16)),
            CountUpText(
              value: value,
              formatter: formatter,
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
