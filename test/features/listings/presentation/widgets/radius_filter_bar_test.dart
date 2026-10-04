import 'package:book_bridge/features/listings/presentation/widgets/radius_filter_bar.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  test('formatRadiusKm drops trailing .0', () {
    expect(formatRadiusKm(1), '1');
    expect(formatRadiusKm(2.5), '2.5');
  });

  testWidgets('selecting a preset reports its value', (tester) async {
    double? picked = -1;
    await tester.pumpWidget(
      _wrap(RadiusFilterBar(selectedKm: null, onChanged: (v) => picked = v)),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Within 2 km'));
    await tester.pump();

    expect(picked, 2);
  });

  testWidgets('tapping "Any" clears the radius', (tester) async {
    double? picked = -1;
    await tester.pumpWidget(
      _wrap(RadiusFilterBar(selectedKm: 5, onChanged: (v) => picked = v)),
    );

    final any = tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
    expect(any.selected, isFalse);
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();

    expect(picked, isNull);
  });

  testWidgets('map chip only shows when onOpenMap is provided', (tester) async {
    await tester.pumpWidget(
      _wrap(RadiusFilterBar(selectedKm: null, onChanged: (_) {})),
    );
    await tester.drag(find.byType(ListView), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);

    var opened = false;
    await tester.pumpWidget(
      _wrap(
        RadiusFilterBar(
          selectedKm: null,
          onChanged: (_) {},
          onOpenMap: () => opened = true,
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ActionChip));
    expect(opened, isTrue);
  });
}
