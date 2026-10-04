import 'package:book_bridge/features/subscriptions/presentation/widgets/power_seller_widgets.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('PowerSellerBadge shows the localized label', (tester) async {
    await tester.pumpWidget(_wrap(const PowerSellerBadge()));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PowerSellerBadge)),
    )!;
    expect(find.text(l10n.powerSellerBadge), findsOneWidget);
  });

  testWidgets('upgrade card calls onTap when idle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(PowerSellerUpgradeCard(onTap: () => taps++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PowerSellerUpgradeCard));
    expect(taps, 1);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('upgrade card ignores taps and shows spinner while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(PowerSellerUpgradeCard(onTap: () => taps++, loading: true)),
    );

    await tester.tap(find.byType(PowerSellerUpgradeCard));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
