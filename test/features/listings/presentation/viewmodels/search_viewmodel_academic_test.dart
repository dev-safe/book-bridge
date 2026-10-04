import 'dart:async';

import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/category.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/search_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/search_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockSearchListingsUseCase extends Mock implements SearchListingsUseCase {}

class _FakeSearchParams extends Fake implements SearchListingsParams {}

const _school = School(id: 'sch-1', name: 'GBHS Molyko');
const _category = Category(
  id: 'cat-1',
  name: 'Science',
  icon: Icons.science,
  subtitle: 'Physics, Chemistry',
);

Listing _listing(String id) => Listing(
  id: id,
  title: 'Book $id',
  author: 'Author',
  priceFcfa: 2000,
  condition: BookCondition.good,
  imageUrl: 'https://cdn.example.com/$id.jpg',
  description: '',
  sellerId: 'seller-1',
  status: 'available',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  late MockListingRepository repository;
  late MockSearchListingsUseCase searchUseCase;
  late SearchViewModel viewModel;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeSearchParams());
    registerFallbackValue(AcademicFilters.none);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockListingRepository();
    searchUseCase = MockSearchListingsUseCase();
    when(() => repository.getCategories()).thenAnswer((_) async => right([]));
    when(() => repository.getClassLevels()).thenAnswer((_) async => right([]));
    when(() => repository.getSubjects()).thenAnswer((_) async => right([]));
    viewModel = SearchViewModel(
      searchListingsUseCase: searchUseCase,
      repository: repository,
    );
    await pumpEventQueue();
  });

  group('filter-only browsing', () {
    test('picking a filter with no query browses listings', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => right([_listing('a')]));

      await viewModel.setClassLevelFilter('cl-1');

      final filters =
          verify(
                () => repository.getListings(
                  filters: captureAny(named: 'filters'),
                ),
              ).captured.single
              as AcademicFilters;
      expect(filters, const AcademicFilters(classLevelId: 'cl-1'));
      expect(viewModel.searchState, SearchState.success);
      expect(viewModel.searchResults.map((l) => l.id), ['a']);
      verifyNever(() => searchUseCase(any()));
    });

    test('an empty result is reported as empty', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => right([]));

      await viewModel.setSubjectFilter('sub-1');

      expect(viewModel.searchState, SearchState.empty);
    });

    test('a failure is surfaced as an error', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => left(const ServerFailure(message: 'offline')));

      await viewModel.setSchoolFilter(_school);

      expect(viewModel.searchState, SearchState.error);
      expect(viewModel.errorMessage, 'offline');
    });

    test('clearing every filter returns to the idle state', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => right([_listing('a')]));
      await viewModel.setClassLevelFilter('cl-1');

      await viewModel.clearAcademicFilters();

      expect(viewModel.searchState, SearchState.initial);
      expect(viewModel.searchResults, isEmpty);
    });

    test('clearSearch keeps browsing by active filters', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => right([_listing('a')]));
      await viewModel.setClassLevelFilter('cl-1');

      viewModel.clearSearch();
      await pumpEventQueue();

      verify(
        () => repository.getListings(filters: any(named: 'filters')),
      ).called(2);
      expect(viewModel.searchState, SearchState.success);
    });
  });

  group('combined with a query or category', () {
    test('a query search carries the active filters', () async {
      when(
        () => repository.getListings(filters: any(named: 'filters')),
      ).thenAnswer((_) async => right([]));
      when(
        () => searchUseCase(any()),
      ).thenAnswer((_) async => right([_listing('q')]));
      await viewModel.setSubjectFilter('sub-1');

      await viewModel.search('physics');

      final params =
          verify(() => searchUseCase(captureAny())).captured.single
              as SearchListingsParams;
      expect(params.query, 'physics');
      expect(params.filters, const AcademicFilters(subjectId: 'sub-1'));
    });

    test('changing a filter re-runs the active query', () async {
      when(
        () => searchUseCase(any()),
      ).thenAnswer((_) async => right([_listing('q')]));
      await viewModel.search('physics');

      await viewModel.setClassLevelFilter('cl-1');

      final captured = verify(() => searchUseCase(captureAny())).captured;
      expect(captured, hasLength(2));
      final last = captured.last as SearchListingsParams;
      expect(last.query, 'physics');
      expect(last.filters.classLevelId, 'cl-1');
      verifyNever(() => repository.getListings(filters: any(named: 'filters')));
    });

    test('changing a filter re-runs the active category', () async {
      when(
        () => repository.getListings(
          category: any(named: 'category'),
          filters: any(named: 'filters'),
        ),
      ).thenAnswer((_) async => right([_listing('c')]));
      await viewModel.searchByCategory(_category);

      await viewModel.setSchoolFilter(_school);

      final captured = verify(
        () => repository.getListings(
          category: 'Science',
          filters: captureAny(named: 'filters'),
        ),
      ).captured;
      expect(captured.last, const AcademicFilters(schoolId: 'sch-1'));
    });
  });

  test('a stale response does not overwrite newer results', () async {
    final slow = Completer<Either<Failure, List<Listing>>>();
    when(
      () => repository.getListings(filters: any(named: 'filters')),
    ).thenAnswer((_) => slow.future);
    when(
      () => searchUseCase(any()),
    ).thenAnswer((_) async => right([_listing('fresh')]));

    final pending = viewModel.setClassLevelFilter('cl-1');
    await viewModel.search('physics');
    slow.complete(right([_listing('stale')]));
    await pending;

    expect(viewModel.searchResults.map((l) => l.id), ['fresh']);
    expect(viewModel.searchState, SearchState.success);
  });
}
