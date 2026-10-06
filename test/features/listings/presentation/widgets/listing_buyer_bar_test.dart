import 'package:book_bridge/features/listings/presentation/widgets/listing_buyer_bar.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int chatTaps;
  late int buyTaps;

  setUp(() {
    chatTaps = 0;
    buyTaps = 0;
  });

  Future<void> pumpBar(WidgetTester tester, {required bool isAvailable}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: ListingBuyerBar(
              priceFcfa: 2500,
              isAvailable: isAvailable,
              onChat: () => chatTaps++,
              onBuy: () => buyTaps++,
            ),
          ),
        ),
      );

  testWidgets('available listing shows price, chat and buy actions', (
    tester,
  ) async {
    await pumpBar(tester, isAvailable: true);

    expect(find.text('Price'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.tap(find.text('Buy Now'));

    expect(chatTaps, 1);
    expect(buyTaps, 1);
  });

  testWidgets('sold listing hides chat and disables buy', (tester) async {
    await pumpBar(tester, isAvailable: false);

    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.text('SOLD'), findsOneWidget);

    await tester.tap(find.text('SOLD'));
    expect(buyTaps, 0);
  });

  testWidgets('fits a narrow screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpBar(tester, isAvailable: true);

    expect(tester.takeException(), isNull);
  });
}
