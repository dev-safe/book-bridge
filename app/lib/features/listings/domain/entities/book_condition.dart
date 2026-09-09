import 'package:book_bridge/l10n/app_localizations.dart';

/// Standardized book condition categories for the BookBridge marketplace.
enum BookCondition {
  brandNew('new'),
  likeNew('like_new'),
  good('good'),
  fair('fair'),
  poor('poor');

  final String value;

  const BookCondition(this.value);

  /// Helper to convert a Supabase DB string back to a [BookCondition] enum.
  /// Legacy 'excellent' is parsed as [good] for safety.
  static BookCondition fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'new':
        return BookCondition.brandNew;
      case 'like_new':
      case 'like new':
        return BookCondition.likeNew;
      case 'good':
      case 'excellent': // Graceful legacy fallback
        return BookCondition.good;
      case 'fair':
        return BookCondition.fair;
      case 'poor':
        return BookCondition.poor;
      default:
        return BookCondition.good; // Safe default
    }
  }

  /// Consolidates localized presentation label for this condition.
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case BookCondition.brandNew:
        return l10n.conditionNew;
      case BookCondition.likeNew:
        return l10n.conditionLikeNew;
      case BookCondition.good:
        return l10n.conditionGood;
      case BookCondition.fair:
        return l10n.conditionFair;
      case BookCondition.poor:
        return l10n.conditionPoor;
    }
  }
}
