import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/impact/domain/usecases/get_platform_stats_usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockGetListingsUseCase extends Mock implements GetListingsUseCase {}

class MockGetPlatformStatsUseCase extends Mock
    implements GetPlatformStatsUseCase {}

class _FakeGetListingsParams extends Fake implements GetListingsParams {}

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

Position _position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 10, 1),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late HomeViewModel viewModel;
  late LocationViewModel location;

  setUpAll(() => registerFallbackValue(_FakeGetListingsParams()));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockListingRepository();
    final getListings = MockGetListingsUseCase();
    final getStats = MockGetPlatformStatsUseCase();
    when(() => repository.getCategories()).thenAnswer((_) async => right([]));
    when(() => repository.getClassLevels()).thenAnswer((_) async => right([]));
    when(() => repository.getSubjects()).thenAnswer((_) async => right([]));
    when(() => repository.isServingFromCache).thenReturn(false);
    when(
      () => getStats(),
    ).thenAnswer((_) async => left(const ServerFailure(message: 'offline')));
    when(() => getListings(any())).thenAnswer(
      (_) async => right([
        _listing('near', lat: 4.1567, lng: 9.2410),
        _listing('far', lat: 4.0511, lng: 9.7679),
        _listing('unknown'),
      ]),
    );

    location = LocationViewModel(initialValue: false);
    viewModel = HomeViewModel(
      getListingsUseCase: getListings,
      locationViewModel: location,
      listingRepository: repository,
      getPlatformStatsUseCase: getStats,
    );
    await pumpEventQueue();
  });

  tearDown(() => viewModel.dispose());

  test('defaults to "Any" and shows every listing', () {
    expect(viewModel.radiusKm, isNull);
    expect(viewModel.isRadiusActive, isFalse);
    expect(viewModel.filteredListings, hasLength(3));
  });

  test('radius has no effect until the user position is known', () {
    viewModel.setRadiusKm(5);

    expect(viewModel.isRadiusActive, isFalse);
    expect(viewModel.filteredListings, hasLength(3));
  });

  test('active radius keeps only nearby listings with coordinates', () {
    viewModel.setCurrentPositionForTesting(_position(4.1527, 9.2410));
    viewModel.setRadiusKm(5);

    expect(viewModel.isRadiusActive, isTrue);
    expect(viewModel.filteredListings.map((l) => l.id), ['near']);
  });

  test('setting "Any" again restores all listings', () {
    viewModel.setCurrentPositionForTesting(_position(4.1527, 9.2410));
    viewModel.setRadiusKm(1);
    viewModel.setRadiusKm(null);

    expect(viewModel.filteredListings, hasLength(3));
  });
}
