import 'package:book_bridge/core/utils/listing_share.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Listing _listing({String? schoolName}) => Listing(
  id: '0b6f2c1e-1234-4abc-9def-1234567890ab',
  title: 'Physics Form 5',
  author: 'J. Doe',
  priceFcfa: 3500,
  condition: BookCondition.good,
  imageUrl: '',
  description: 'Call me on 677123456',
  sellerId: 'seller-1',
  status: 'available',
  createdAt: DateTime(2026),
  sellerName: 'Alice Seller',
  sellerLocality: 'Bastos',
  schoolName: schoolName,
  meetupSpot: 'Main gate',
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('listingShareUrl points at the public /l/ route', () {
    expect(
      listingShareUrl('abc-123'),
      'https://bookbridge.devsafe.cm/l/abc-123',
    );
  });

  test('share text includes book details, school and link', () {
    final text = buildListingShareText(
      _listing(schoolName: 'Lycée Leclerc'),
      en,
    );

    expect(text, contains('Physics Form 5'));
    expect(text, contains('J. Doe'));
    expect(text, contains(en.priceFormat(3500)));
    expect(text, contains(BookCondition.good.localizedLabel(en)));
    expect(text, contains('${en.shareTextSchool}: Lycée Leclerc'));
    expect(
      text,
      contains(
        'https://bookbridge.devsafe.cm/l/0b6f2c1e-1234-4abc-9def-1234567890ab',
      ),
    );
  });

  test('share text omits seller identity and contact details', () {
    final text = buildListingShareText(_listing(schoolName: 'X'), en);

    expect(text, isNot(contains('Alice Seller')));
    expect(text, isNot(contains('Bastos')));
    expect(text, isNot(contains('677123456')));
    expect(text, isNot(contains('Main gate')));
    expect(text, isNot(contains('wa.me')));
    expect(text, isNot(contains('tel:')));
  });

  test('school line is skipped when the listing has no school', () {
    final text = buildListingShareText(_listing(), fr);

    expect(text, isNot(contains(fr.shareTextSchool)));
    expect(text, contains(fr.shareTextViewListing));
  });
}
