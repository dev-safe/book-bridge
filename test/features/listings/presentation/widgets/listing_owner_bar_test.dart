import 'package:book_bridge/features/listings/presentation/widgets/listing_owner_bar.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int editTaps;
  late int boostTaps;

  setUp(() {
    editTaps = 0;
    boostTaps = 0;
  });

  Future<void> pumpBar(WidgetTester tester, {required bool canBoost}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: ListingOwnerBar(
              onEdit: () => editTaps++,
              onBoost: canBoost ? () => boostTaps++ : null,
            ),
          ),
        ),
      );

  testWidgets('owner can edit the listing', (tester) async {
    await pumpBar(tester, canBoost: false);

    await tester.tap(find.text('Edit Listing'));

    expect(editTaps, 1);
  });

  testWidgets('boost is hidden when paid features are off', (tester) async {
    await pumpBar(tester, canBoost: false);

    expect(find.byIcon(Icons.rocket_launch), findsNothing);
  });

  testWidgets('boost sits above edit when paid features are on', (
    tester,
  ) async {
    await pumpBar(tester, canBoost: true);

    await tester.tap(find.byIcon(Icons.rocket_launch));
    await tester.tap(find.text('Edit Listing'));

    expect(boostTaps, 1);
    expect(editTaps, 1);
  });
}
