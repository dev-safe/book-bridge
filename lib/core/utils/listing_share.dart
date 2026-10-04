import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

/// Public web host that serves listing previews and Android App Links.
const String kShareBaseUrl = 'https://bookbridge.devsafe.cm';

/// Public link for a listing. Opens the app when installed, otherwise
/// shows a web preview with a download link.
String listingShareUrl(String listingId) =>
    '$kShareBaseUrl/l/${Uri.encodeComponent(listingId)}';

/// Builds the share message for a listing.
///
/// Intentionally excludes seller name, phone and any contact details:
/// buyers must open the link and use in-app inquiry/escrow.
String buildListingShareText(Listing listing, AppLocalizations l10n) {
  final school = listing.schoolName?.trim();
  final lines = <String>[
    l10n.shareTextCheckOut,
    '📚 ${listing.title} — ${listing.author}',
    '💰 ${l10n.priceFormat(listing.priceFcfa)}',
    '🔍 ${l10n.shareTextCondition}: ${listing.condition.localizedLabel(l10n)}',
    if (school != null && school.isNotEmpty)
      '🏫 ${l10n.shareTextSchool}: $school',
    '',
    l10n.shareTextViewListing,
    listingShareUrl(listing.id),
  ];
  return lines.join('\n');
}
