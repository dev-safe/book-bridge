import 'package:book_bridge/features/listings/presentation/widgets/listing_image_carousel.dart';
import 'package:book_bridge/features/listings/presentation/widgets/listing_photos_picker.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _carousel(List<String> urls) =>
    _wrap(SizedBox(height: 300, child: ListingImageCarousel(imageUrls: urls)));

const _a = 'https://cdn.example.com/a.jpg';
const _b = 'https://cdn.example.com/b.jpg';
const _c = 'https://cdn.example.com/c.jpg';

void main() {
  group('ListingImageCarousel', () {
    testWidgets('single photo has no page dots', (tester) async {
      await tester.pumpWidget(_carousel(const [_a]));

      expect(find.byKey(const Key('listing-carousel')), findsOneWidget);
      expect(find.byKey(const Key('listing-carousel-dots')), findsNothing);
    });

    testWidgets('multiple photos show page dots', (tester) async {
      await tester.pumpWidget(_carousel(const [_a, _b]));

      expect(find.byKey(const Key('listing-carousel-dots')), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 1 of 2'), findsOneWidget);
    });

    testWidgets('no photos shows a placeholder', (tester) async {
      await tester.pumpWidget(_carousel(const []));

      expect(find.byKey(const Key('listing-carousel')), findsNothing);
    });
  });

  group('ListingPhotosPicker', () {
    Widget picker(
      List<String> urls, {
      VoidCallback? onAdd,
      ValueChanged<int>? onRemove,
      ValueChanged<int>? onSetCover,
    }) => _wrap(
      ListingPhotosPicker(
        imageUrls: urls,
        maxImages: 3,
        isUploading: false,
        onAdd: onAdd ?? () {},
        onRemove: onRemove ?? (_) {},
        onSetCover: onSetCover ?? (_) {},
      ),
    );

    testWidgets('empty picker adds a photo on tap', (tester) async {
      var added = 0;
      await tester.pumpWidget(picker(const [], onAdd: () => added++));

      await tester.tap(find.text('Add book photos'));
      expect(added, 1);
      expect(find.byKey(const ValueKey('photo-thumb-0')), findsNothing);
    });

    testWidgets('shows add tile while below the cap', (tester) async {
      await tester.pumpWidget(picker(const [_a, _b]));

      expect(find.byKey(const ValueKey('photo-thumb-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-add')), findsOneWidget);
    });

    testWidgets('hides add tile at the cap', (tester) async {
      await tester.pumpWidget(picker(const [_a, _b, _c]));

      expect(find.byKey(const ValueKey('photo-thumb-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-add')), findsNothing);
    });

    testWidgets('tapping a thumbnail makes it the cover', (tester) async {
      int? cover;
      await tester.pumpWidget(
        picker(const [_a, _b], onSetCover: (i) => cover = i),
      );

      await tester.tap(find.byKey(const ValueKey('photo-thumb-1')));
      expect(cover, 1);
    });

    testWidgets('remove button reports the index', (tester) async {
      int? removed;
      await tester.pumpWidget(
        picker(const [_a, _b], onRemove: (i) => removed = i),
      );

      await tester.tap(find.byTooltip('Remove photo').last);
      expect(removed, 1);
    });
  });
}
