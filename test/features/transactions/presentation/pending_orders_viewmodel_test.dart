import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/usecases/get_user_transactions_usecase.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/pending_orders_viewmodel.dart';
import 'package:book_bridge/features/transactions/presentation/widgets/orders_shortcuts.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockGetUserTransactionsUseCase extends Mock
    implements GetUserTransactionsUseCase {}

TransactionEntity _tx(String id, String status) => TransactionEntity(
  id: id,
  listingId: 'lst-$id',
  listingTitle: 'Book $id',
  listingImageUrl: '',
  buyerId: 'buyer',
  sellerId: 'seller',
  amountFcfa: 1000,
  status: status,
  externalRef: 'ref-$id',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  late MockGetUserTransactionsUseCase useCase;
  late PendingOrdersViewModel viewModel;

  setUp(() {
    useCase = MockGetUserTransactionsUseCase();
    viewModel = PendingOrdersViewModel(useCase: useCase);
  });

  void stub({
    Either<Failure, List<TransactionEntity>>? purchases,
    Either<Failure, List<TransactionEntity>>? sales,
  }) {
    when(
      () => useCase.purchases('u1'),
    ).thenAnswer((_) async => purchases ?? const Right([]));
    when(
      () => useCase.sales('u1'),
    ).thenAnswer((_) async => sales ?? const Right([]));
  }

  group('PendingOrdersViewModel', () {
    test('counts only held purchases and sales', () async {
      stub(
        purchases: Right([
          _tx('1', 'held'),
          _tx('2', 'successful'),
          _tx('3', 'held'),
        ]),
        sales: Right([_tx('4', 'held'), _tx('5', 'disputed')]),
      );

      await viewModel.refresh('u1');

      expect(viewModel.purchasesToConfirm, 2);
      expect(viewModel.salesInEscrow, 1);
      expect(viewModel.totalCount, 3);
      expect(viewModel.hasPending, isTrue);
    });

    test(
      'null or empty user id resets counts without calling use case',
      () async {
        stub(purchases: Right([_tx('1', 'held')]));
        await viewModel.refresh('u1');

        await viewModel.refresh(null);
        expect(viewModel.totalCount, 0);
        await viewModel.refresh('');
        expect(viewModel.hasPending, isFalse);
        verify(() => useCase.purchases('u1')).called(1);
      },
    );

    test('keeps previous counts when a request fails', () async {
      stub(
        purchases: Right([_tx('1', 'held')]),
        sales: Right([_tx('2', 'held')]),
      );
      await viewModel.refresh('u1');

      stub(
        purchases: const Left(ServerFailure(message: 'offline')),
        sales: const Right([]),
      );
      await viewModel.refresh('u1');

      expect(viewModel.purchasesToConfirm, 1);
      expect(viewModel.salesInEscrow, 0);
    });

    test('notifies listeners only when counts change', () async {
      stub(purchases: Right([_tx('1', 'held')]));
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.refresh('u1');
      await viewModel.refresh('u1');

      expect(notifications, 1);
    });

    test('clear resets counts', () async {
      stub(purchases: Right([_tx('1', 'held')]));
      await viewModel.refresh('u1');

      viewModel.clear();

      expect(viewModel.totalCount, 0);
    });
  });

  group('PendingOrdersCard', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<PendingOrdersViewModel>.value(
          value: viewModel,
          child: const Scaffold(body: PendingOrdersCard()),
        ),
      ),
    );

    testWidgets('is hidden when nothing is pending', (tester) async {
      await pump(tester);

      expect(find.text('Orders need your attention'), findsNothing);
    });

    testWidgets('shows purchase and sale lines when pending', (tester) async {
      stub(
        purchases: Right([_tx('1', 'held'), _tx('2', 'held')]),
        sales: Right([_tx('3', 'held')]),
      );
      await viewModel.refresh('u1');

      await pump(tester);

      expect(find.text('Orders need your attention'), findsOneWidget);
      expect(
        find.text('2 purchases: confirm you received the books'),
        findsOneWidget,
      );
      expect(
        find.text('1 sale: hand over the book to get paid'),
        findsOneWidget,
      );
    });
  });
}
