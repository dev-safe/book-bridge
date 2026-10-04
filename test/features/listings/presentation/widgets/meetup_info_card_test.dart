import 'package:book_bridge/features/listings/presentation/widgets/meetup_info_card.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders nothing without a spot or pin', (tester) async {
    await tester.pumpWidget(_wrap(const MeetupInfoCard(spot: '  ')));

    expect(find.text('Meetup spot'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shows the spot and Open in Maps when pinned', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupInfoCard(
          spot: ' UB Main Gate ',
          latitude: 4.152,
          longitude: 9.289,
        ),
      ),
    );

    expect(find.text('Meetup spot'), findsOneWidget);
    expect(find.text('UB Main Gate'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
  });

  testWidgets('pin without a spot shows the pin-only label', (tester) async {
    await tester.pumpWidget(
      _wrap(const MeetupInfoCard(latitude: 4.152, longitude: 9.289)),
    );

    expect(find.text('Pinned on map'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
  });

  testWidgets('spot without a pin hides Open in Maps', (tester) async {
    await tester.pumpWidget(_wrap(const MeetupInfoCard(spot: 'Library')));

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Open in Maps'), findsNothing);
  });

  testWidgets('safety hint can be hidden', (tester) async {
    await tester.pumpWidget(_wrap(const MeetupInfoCard(spot: 'Library')));
    expect(find.textContaining('busy public place'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const MeetupInfoCard(spot: 'Library', showSafetyHint: false)),
    );
    expect(find.textContaining('busy public place'), findsNothing);
  });

  test('meetupMapsUri builds a Google Maps search URL', () {
    expect(
      meetupMapsUri(4.152, 9.289).toString(),
      'https://www.google.com/maps/search/?api=1&query=4.152,9.289',
    );
  });
}
