import 'package:book_bridge/core/location/location_access.dart';
import 'package:book_bridge/features/listings/presentation/widgets/location_prompt_card.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({int actions, int dismissals})> pumpCard(
    WidgetTester tester,
    LocationAccessStatus status, {
    double width = 400,
  }) async {
    var actions = 0;
    var dismissals = 0;
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocationPromptCard(
            status: status,
            onAction: () => actions++,
            onDismiss: () => dismissals++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Not now'));
    final label = switch (status) {
      LocationAccessStatus.serviceDisabled => 'Turn on location',
      LocationAccessStatus.deniedForever => 'Open settings',
      _ => 'Allow location',
    };
    await tester.tap(find.text(label));
    return (actions: actions, dismissals: dismissals);
  }

  testWidgets('GPS off offers "Turn on location"', (tester) async {
    final calls = await pumpCard(tester, LocationAccessStatus.serviceDisabled);

    expect(find.text('See books near you'), findsOneWidget);
    expect(calls.actions, 1);
    expect(calls.dismissals, 1);
  });

  testWidgets('denied offers "Allow location"', (tester) async {
    final calls = await pumpCard(tester, LocationAccessStatus.denied);

    expect(calls.actions, 1);
  });

  testWidgets('blocked offers "Open settings"', (tester) async {
    final calls = await pumpCard(tester, LocationAccessStatus.deniedForever);

    expect(calls.actions, 1);
  });

  testWidgets('fits a 320dp screen without overflow', (tester) async {
    await pumpCard(tester, LocationAccessStatus.deniedForever, width: 320);

    expect(tester.takeException(), isNull);
  });
}
