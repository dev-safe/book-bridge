import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/domain/entities/moderation_failure.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:book_bridge/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(ReportReason, String?)> submitted;
  bool? sent;

  Future<void> open(WidgetTester tester, {Failure? result}) async {
    submitted = [];
    sent = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                sent = await showReportSheet(
                  context,
                  title: 'Report listing',
                  onSubmit: (reason, details) async {
                    submitted.add((reason, details));
                    return result;
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder sendButton() => find.widgetWithText(FilledButton, 'Send report');

  Future<void> send(WidgetTester tester) async {
    await tester.ensureVisible(sendButton());
    await tester.pumpAndSettle();
    await tester.tap(sendButton());
    await tester.pumpAndSettle();
  }

  testWidgets('needs a reason before sending', (tester) async {
    await open(tester);

    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);

    await tester.tap(find.text('Scam or fraud'));
    await tester.pump();

    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
  });

  testWidgets('sends the reason and details, then closes', (tester) async {
    await open(tester);

    await tester.tap(find.text('Scam or fraud'));
    await tester.enterText(find.byType(TextField), 'Wants money first');
    await send(tester);

    expect(submitted, [(ReportReason.scam, 'Wants money first')]);
    expect(sent, isTrue);
    expect(find.byType(ReportSheet), findsNothing);
  });

  testWidgets('stays open and explains the daily limit', (tester) async {
    await open(
      tester,
      result: const ModerationFailure(
        message: 'limit',
        kind: ModerationFailureKind.reportLimit,
      ),
    );

    await tester.tap(find.text('Spam or misleading'));
    await send(tester);

    expect(find.byType(ReportSheet), findsOneWidget);
    expect(find.textContaining('too many reports'), findsOneWidget);
    expect(sent, isNull);
  });

  testWidgets('shows a generic error for other failures', (tester) async {
    await open(tester, result: const ServerFailure(message: 'boom'));

    await tester.tap(find.text('Something else'));
    await send(tester);

    expect(find.textContaining("didn't work"), findsOneWidget);
  });
}
