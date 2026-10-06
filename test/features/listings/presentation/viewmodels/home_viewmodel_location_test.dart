import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/location/location_access.dart';
import 'package:book_bridge/features/impact/domain/usecases/get_platform_stats_usecase.dart';
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

class FakeLocationAccess implements LocationAccess {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission? permissionAfterRequest;
  int requestCalls = 0;
  int openLocationSettingsCalls = 0;
  int openAppSettingsCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    permission = permissionAfterRequest ?? permission;
    return permission;
  }

  @override
  Future<Position> currentPosition() async => Position(
    latitude: 4.15,
    longitude: 9.24,
    timestamp: DateTime(2026, 10, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

void main() {
  late MockListingRepository repository;
  late MockGetListingsUseCase getListings;
  late MockGetPlatformStatsUseCase getStats;
  late FakeLocationAccess access;
  late LocationViewModel location;
  HomeViewModel? viewModel;

  setUpAll(() => registerFallbackValue(_FakeGetListingsParams()));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockListingRepository();
    getListings = MockGetListingsUseCase();
    getStats = MockGetPlatformStatsUseCase();
    when(() => repository.getCategories()).thenAnswer((_) async => right([]));
    when(() => repository.getClassLevels()).thenAnswer((_) async => right([]));
    when(() => repository.getSubjects()).thenAnswer((_) async => right([]));
    when(() => repository.isServingFromCache).thenReturn(false);
    when(
      () => getStats(),
    ).thenAnswer((_) async => left(const ServerFailure(message: 'offline')));
    when(() => getListings(any())).thenAnswer((_) async => right([]));
    access = FakeLocationAccess();
    location = LocationViewModel(initialValue: true);
  });

  tearDown(() {
    viewModel?.dispose();
    viewModel = null;
  });

  Future<HomeViewModel> build() async {
    final vm = HomeViewModel(
      getListingsUseCase: getListings,
      locationViewModel: location,
      listingRepository: repository,
      getPlatformStatsUseCase: getStats,
      locationAccess: access,
    );
    viewModel = vm;
    await pumpEventQueue();
    return vm;
  }

  test('granted access stores the position and hides the prompt', () async {
    final vm = await build();

    expect(vm.locationStatus, LocationAccessStatus.granted);
    expect(vm.currentPosition, isNotNull);
    expect(vm.showLocationPrompt, isFalse);
  });

  test('GPS off shows the prompt and opens location settings', () async {
    access.serviceEnabled = false;
    final vm = await build();

    expect(vm.locationStatus, LocationAccessStatus.serviceDisabled);
    expect(vm.showLocationPrompt, isTrue);

    await vm.resolveLocationAccess();
    expect(access.openLocationSettingsCalls, 1);
  });

  test('re-checks after resuming from settings with GPS on', () async {
    access.serviceEnabled = false;
    final vm = await build();

    access.serviceEnabled = true;
    await vm.onAppResumed();

    expect(vm.locationStatus, LocationAccessStatus.granted);
    expect(vm.currentPosition, isNotNull);
    expect(vm.showLocationPrompt, isFalse);
  });

  test('denied permission asks again only when the user taps Allow', () async {
    access.permission = LocationPermission.denied;
    final vm = await build();

    expect(vm.locationStatus, LocationAccessStatus.denied);
    expect(access.requestCalls, 1);

    await vm.onAppResumed();
    expect(access.requestCalls, 1, reason: 'resume must not re-prompt');

    access.permissionAfterRequest = LocationPermission.whileInUse;
    await vm.resolveLocationAccess();
    expect(access.requestCalls, 2);
    expect(vm.locationStatus, LocationAccessStatus.granted);
  });

  test('permanently denied opens the app settings', () async {
    access.permission = LocationPermission.deniedForever;
    final vm = await build();

    expect(vm.locationStatus, LocationAccessStatus.deniedForever);
    expect(vm.showLocationPrompt, isTrue);

    await vm.resolveLocationAccess();
    expect(access.openAppSettingsCalls, 1);
  });

  test('"Not now" hides the prompt for the session', () async {
    access.serviceEnabled = false;
    final vm = await build();

    vm.dismissLocationPrompt();

    expect(vm.showLocationPrompt, isFalse);
  });

  test('no prompt and no GPS calls when the in-app toggle is off', () async {
    location = LocationViewModel(initialValue: false);
    access.serviceEnabled = false;
    final vm = await build();

    expect(vm.locationStatus, LocationAccessStatus.unknown);
    expect(vm.showLocationPrompt, isFalse);
  });

  test('turning the in-app toggle off clears the prompt', () async {
    access.serviceEnabled = false;
    final vm = await build();
    expect(vm.showLocationPrompt, isTrue);

    await location.setEnabled(false);

    expect(vm.locationStatus, LocationAccessStatus.unknown);
    expect(vm.showLocationPrompt, isFalse);
  });
}
