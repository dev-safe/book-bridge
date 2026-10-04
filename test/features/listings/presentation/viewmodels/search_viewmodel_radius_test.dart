import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/search_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/search_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockSearchListingsUseCase extends Mock implements SearchListingsUseCase {}

class _FakeSearchParams extends Fake implements SearchListingsParams {}

// Origin in Buea; "near" is ~1 km away, "far" is ~60 km away (Douala).
const _originLat = 4.1560;
const _originLng = 9.2310;

Listing _listing(String id, {double? lat, double? lng}) => Listing(
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
  latitude: lat,
  longitude: lng,
);

final _near = _listing('near', lat: 4.1650, lng: 9.2310);
final _far = _listing('far', lat: 4.0511, lng: 9.7679);
final _noCoords = _listing('none');

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
    when(
      () => repository.getListings(filters: any(named: 'filters')),
    ).thenAnswer((_) async => right([_near, _far, _noCoords]));
    viewModel = SearchViewModel(
      searchListingsUseCase: searchUseCase,
      repository: repository,
    );
    await pumpEventQueue();
  });

  test('picking a radius with nothing else active browses listings', () async {
    await viewModel.setRadiusKm(5);

    verify(
      () => repository.getListings(filters: any(named: 'filters')),
    ).called(1);
    expect(viewModel.radiusKm, 5);
    expect(viewModel.searchState, SearchState.success);
  });

  test('resultsWithin keeps only listings inside the radius', () async {
    await viewModel.setRadiusKm(5);

    final visible = viewModel.resultsWithin(
      originLat: _originLat,
      originLng: _originLng,
    );

    expect(visible.map((l) => l.id), ['near']);
  });

  test('resultsWithin returns everything when origin is unknown', () async {
    await viewModel.setRadiusKm(5);

    final visible = viewModel.resultsWithin(originLat: null, originLng: null);

    expect(visible, hasLength(3));
  });

  test('clearing the radius with nothing else active resets', () async {
    await viewModel.setRadiusKm(5);
    await viewModel.setRadiusKm(null);

    expect(viewModel.radiusKm, isNull);
    expect(viewModel.searchState, SearchState.initial);
    expect(viewModel.searchResults, isEmpty);
  });

  test('changing the radius with a query active does not refetch', () async {
    when(
      () => searchUseCase(any()),
    ).thenAnswer((_) async => right([_near, _far]));
    await viewModel.search('math');
    clearInteractions(repository);
    clearInteractions(searchUseCase);

    await viewModel.setRadiusKm(5);

    verifyNever(() => repository.getListings(filters: any(named: 'filters')));
    verifyNever(() => searchUseCase(any()));
    expect(
      viewModel
          .resultsWithin(originLat: _originLat, originLng: _originLng)
          .map((l) => l.id),
      ['near'],
    );
  });

  test('clearing the query keeps browsing while a radius is set', () async {
    when(() => searchUseCase(any())).thenAnswer((_) async => right([_near]));
    await viewModel.search('math');
    await viewModel.setRadiusKm(10);
    clearInteractions(repository);

    viewModel.clearSearch();
    await pumpEventQueue();

    verify(
      () => repository.getListings(filters: any(named: 'filters')),
    ).called(1);
    expect(viewModel.searchResults, hasLength(3));
  });
}
