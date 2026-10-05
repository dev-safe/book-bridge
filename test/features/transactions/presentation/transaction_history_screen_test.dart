import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/transaction_history_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTransactionHistoryViewModel extends Mock
    implements TransactionHistoryViewModel {}

TransactionEntity _held() => TransactionEntity(
  id: 'tx-1',
  listingId: 'lst-1',
  listingTitle: 'Advanced Level Physics, 7th edition, with worked answers',
  listingImageUrl: '',
  buyerId: 'buyer-1',
  sellerId: 'seller-1',
  amountFcfa: 5300,
  status: 'held',
  externalRef: 'ref-1',
  createdAt: DateTime(2026, 10, 5),
);

void main() {
  late MockTransactionHistoryViewModel viewModel;

  setUp(() {
    viewModel = MockTransactionHistoryViewModel();
    when(() => viewModel.state).thenReturn(TransactionLoadState.loaded);
    when(() => viewModel.error).thenReturn(null);
    when(() => viewModel.isActionLoading).thenReturn(false);
    when(() => viewModel.purchases).thenReturn([_held()]);
    when(() => viewModel.sales).thenReturn(const []);
  });

  Future<void> pumpAt(WidgetTester tester, Locale locale, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TransactionHistoryViewModel>.value(
          value: viewModel,
          child: const TransactionHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final locale in const [Locale('en'), Locale('fr')]) {
    testWidgets(
      'escrow buttons fit a 320px-wide screen (${locale.languageCode})',
      (tester) async {
        await pumpAt(tester, locale, 320);

        final l10n = lookupAppLocalizations(locale);
        expect(find.text(l10n.escrowReportProblem), findsOneWidget);
        expect(find.text(l10n.escrowConfirmReceipt), findsOneWidget);
        expect(tester.takeException(), isNull);

        final problem = tester.getRect(
          find.ancestor(
            of: find.text(l10n.escrowReportProblem),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        final confirm = tester.getRect(
          find.ancestor(
            of: find.text(l10n.escrowConfirmReceipt),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        expect(problem.left, greaterThanOrEqualTo(0));
        expect(confirm.right, lessThanOrEqualTo(320));
        expect(problem.width, moreOrLessEquals(confirm.width, epsilon: 1));
      },
    );
  }
}
