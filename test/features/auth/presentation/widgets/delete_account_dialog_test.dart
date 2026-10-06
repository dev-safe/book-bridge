import 'dart:async';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/auth/presentation/widgets/delete_account_dialog.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:book_bridge/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _l10n = AppLocalizationsEn();

void main() {
  late int deleteCalls;
  late int onDeletedCalls;

  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<void> Function() deleteAccount,
  }) async {
    deleteCalls = 0;
    onDeletedCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmAndDeleteAccount(
                context,
                deleteAccount: () {
                  deleteCalls++;
                  return deleteAccount();
                },
                onDeleted: () async => onDeletedCalls++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() => find.widgetWithText(TextButton, _l10n.deleteAccount);

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(deleteButton());
  }

  testWidgets('delete stays disabled until the user ticks the checkbox', (
    tester,
  ) async {
    await pumpHost(tester, deleteAccount: () async {});

    expect(find.text(_l10n.deleteAccountTitle), findsOneWidget);
    expect(tester.widget<TextButton>(deleteButton()).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<TextButton>(deleteButton()).onPressed, isNotNull);
  });

  testWidgets('cancel deletes nothing', (tester) async {
    await pumpHost(tester, deleteAccount: () async {});

    await tester.tap(find.text(_l10n.cancel));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(onDeletedCalls, 0);
    expect(find.text(_l10n.deleteAccountTitle), findsNothing);
  });

  testWidgets('success shows progress, then confirms and signs out', (
    tester,
  ) async {
    final completer = Completer<void>();
    await pumpHost(tester, deleteAccount: () => completer.future);

    await confirm(tester);
    await tester.pump();

    expect(find.text(_l10n.deleteAccountInProgress), findsOneWidget);
    expect(deleteCalls, 1);
    expect(onDeletedCalls, 0);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text(_l10n.deleteAccountInProgress), findsNothing);
    expect(find.text(_l10n.deleteAccountSuccess), findsOneWidget);
    expect(onDeletedCalls, 1);
  });

  testWidgets('an order in progress explains why and keeps the account', (
    tester,
  ) async {
    await pumpHost(
      tester,
      deleteAccount: () async =>
          throw ConflictException(message: 'order in progress'),
    );

    await confirm(tester);
    await tester.pumpAndSettle();

    expect(find.text(_l10n.deleteAccountActiveOrdersTitle), findsOneWidget);
    expect(find.text(_l10n.deleteAccountActiveOrders), findsOneWidget);
    expect(onDeletedCalls, 0);
  });

  testWidgets('other failures show an error and keep the account', (
    tester,
  ) async {
    await pumpHost(
      tester,
      deleteAccount: () async => throw ServerException(message: 'boom'),
    );

    await confirm(tester);
    await tester.pumpAndSettle();

    expect(find.text(_l10n.deleteAccountError), findsOneWidget);
    expect(find.text(_l10n.deleteAccountInProgress), findsNothing);
    expect(onDeletedCalls, 0);
  });
}
