import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/update_listing_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/sell_viewmodel.dart';
import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockCreateListingUseCase extends Mock implements CreateListingUseCase {}

class MockUpdateListingUseCase extends Mock implements UpdateListingUseCase {}

class _FakeCreateParams extends Fake implements CreateListingParams {}

class _FakeUpdateParams extends Fake implements UpdateListingParams {}

const _gate = CampusZone(
  id: 'zone-1',
  name: '  UB Main Gate  ',
  university: 'University of Buea',
  city: 'Buea',
  latitude: 4.152345,
  longitude: 9.288871,
  isVerified: true,
);

Listing _listing({
  String? meetupSpot,
  double? meetupLatitude,
  double? meetupLongitude,
}) => Listing(
  id: 'lst-1',
  title: 'Physics',
  author: 'Nelkon',
  priceFcfa: 3000,
  condition: BookCondition.good,
  imageUrl: 'https://cdn.example.com/book.jpg',
  description: '',
  sellerId: 'seller-1',
  status: 'available',
  createdAt: DateTime(2026, 10, 1),
  classLevelId: 'cl-1',
  subjectId: 'sub-1',
  meetupSpot: meetupSpot,
  meetupLatitude: meetupLatitude,
  meetupLongitude: meetupLongitude,
);

void main() {
  late MockCreateListingUseCase createUseCase;
  late MockUpdateListingUseCase updateUseCase;
  late int suggestionCalls;
  late Either<Failure, List<CampusZone>> suggestionResult;
  late SellViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(_FakeCreateParams());
    registerFallbackValue(_FakeUpdateParams());
  });

  setUp(() {
    createUseCase = MockCreateListingUseCase();
    updateUseCase = MockUpdateListingUseCase();
    suggestionCalls = 0;
    suggestionResult = const Right([_gate]);
    viewModel = SellViewModel(
      createListingUseCase: createUseCase,
      updateListingUseCase: updateUseCase,
      repository: MockListingRepository(),
      locationViewModel: LocationViewModel(initialValue: false),
      loadMeetupSuggestions: () async {
        suggestionCalls++;
        return suggestionResult;
      },
    );
  });

  Future<void> fillValidForm() async {
    viewModel
      ..setTitle('Physics')
      ..setAuthor('Nelkon')
      ..setPrice(3000)
      ..setImageUrl('https://cdn.example.com/book.jpg');
    await viewModel.setClassLevel('cl-1');
    await viewModel.setSubject('sub-1');
  }

  group('meetup spot', () {
    test('trims input and clears on blank', () {
      viewModel.setMeetupSpot('  Library steps ');
      expect(viewModel.meetupSpot, 'Library steps');

      viewModel.setMeetupSpot('   ');
      expect(viewModel.meetupSpot, isNull);
    });

    test('rejects spots longer than the DB limit', () async {
      await fillValidForm();
      viewModel.setMeetupSpot('x' * (SellViewModel.maxMeetupSpotLength + 1));

      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.errorMessage, contains('Meetup spot'));
    });

    test('accepts a spot at the limit', () async {
      await fillValidForm();
      viewModel.setMeetupSpot('x' * SellViewModel.maxMeetupSpotLength);

      expect(viewModel.validateForm(), isTrue);
    });
  });

  group('meetup pin', () {
    test('rounds coordinates to 3 decimals', () {
      viewModel.setMeetupPin(4.152345, 9.288871);

      expect(viewModel.meetupLatitude, 4.152);
      expect(viewModel.meetupLongitude, 9.289);
      expect(viewModel.hasMeetupPin, isTrue);
    });

    test('ignores out-of-range coordinates', () {
      viewModel.setMeetupPin(91, 9);
      viewModel.setMeetupPin(4, -181);

      expect(viewModel.hasMeetupPin, isFalse);
    });

    test('clearMeetupPin keeps the spot name', () {
      viewModel
        ..setMeetupSpot('Library')
        ..setMeetupPin(4.1, 9.2)
        ..clearMeetupPin();

      expect(viewModel.hasMeetupPin, isFalse);
      expect(viewModel.meetupSpot, 'Library');
    });
  });

  group('suggestions', () {
    test('applying a zone fills a trimmed name and a rounded pin', () {
      viewModel.applyMeetupSuggestion(_gate);

      expect(viewModel.meetupSpot, 'UB Main Gate');
      expect(viewModel.meetupLatitude, 4.152);
      expect(viewModel.meetupLongitude, 9.289);
    });

    test('long zone names are cut to the limit', () {
      viewModel.applyMeetupSuggestion(
        CampusZone(
          id: 'zone-2',
          name: 'y' * 100,
          university: 'UB',
          city: 'Buea',
          latitude: 4,
          longitude: 9,
        ),
      );

      expect(
        viewModel.meetupSpot,
        hasLength(SellViewModel.maxMeetupSpotLength),
      );
    });

    test('loads once on success', () async {
      await viewModel.loadMeetupSuggestionsIfNeeded();
      await viewModel.loadMeetupSuggestionsIfNeeded();

      expect(suggestionCalls, 1);
      expect(viewModel.meetupSuggestions, [_gate]);
    });

    test('a failure leaves the list empty and allows a retry', () async {
      suggestionResult = const Left(ServerFailure(message: 'down'));
      await viewModel.loadMeetupSuggestionsIfNeeded();

      expect(viewModel.meetupSuggestions, isEmpty);

      suggestionResult = const Right([_gate]);
      await viewModel.loadMeetupSuggestionsIfNeeded();

      expect(suggestionCalls, 2);
      expect(viewModel.meetupSuggestions, [_gate]);
    });
  });

  group('create and update', () {
    test('createListing sends the meetup fields', () async {
      when(
        () => createUseCase(any()),
      ).thenAnswer((_) async => Right(_listing()));
      await fillValidForm();
      viewModel
        ..setMeetupSpot('UB Main Gate')
        ..setMeetupPin(4.152345, 9.288871);

      await viewModel.createListing();

      final params =
          verify(() => createUseCase(captureAny())).captured.single
              as CreateListingParams;
      expect(params.meetupSpot, 'UB Main Gate');
      expect(params.meetupLatitude, 4.152);
      expect(params.meetupLongitude, 9.289);
    });

    test('editing prefills meetup and update always sends it', () async {
      when(
        () => updateUseCase(any()),
      ).thenAnswer((_) async => Right(_listing()));
      viewModel.setEditingListing(
        _listing(
          meetupSpot: 'Library',
          meetupLatitude: 4.1,
          meetupLongitude: 9.2,
        ),
      );
      await pumpEventQueue();

      expect(viewModel.meetupSpot, 'Library');
      expect(viewModel.hasMeetupPin, isTrue);

      viewModel
        ..setMeetupSpot('')
        ..clearMeetupPin();
      await viewModel.updateListing();

      final params =
          verify(() => updateUseCase(captureAny())).captured.single
              as UpdateListingParams;
      expect(params.updateMeetup, isTrue);
      expect(params.meetupSpot, isNull);
      expect(params.meetupLatitude, isNull);
      expect(params.meetupLongitude, isNull);
    });

    test('resetForm clears the meetup', () {
      viewModel
        ..setMeetupSpot('Library')
        ..setMeetupPin(4.1, 9.2)
        ..resetForm();

      expect(viewModel.meetupSpot, isNull);
      expect(viewModel.hasMeetupPin, isFalse);
    });
  });
}
