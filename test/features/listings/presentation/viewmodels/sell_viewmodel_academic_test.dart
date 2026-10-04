import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/update_listing_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/sell_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockCreateListingUseCase extends Mock implements CreateListingUseCase {}

class MockUpdateListingUseCase extends Mock implements UpdateListingUseCase {}

class _FakeCreateParams extends Fake implements CreateListingParams {}

class _FakeUpdateParams extends Fake implements UpdateListingParams {}

const _molyko = School(id: 'sch-1', name: 'GBHS Molyko', town: 'Buea');
const _bilingual = School(id: 'sch-2', name: 'Bilingual Grammar School');

Listing _listing({String id = 'lst-1', String? schoolId}) => Listing(
  id: id,
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
  schoolId: schoolId,
);

void main() {
  late MockListingRepository repository;
  late MockCreateListingUseCase createUseCase;
  late MockUpdateListingUseCase updateUseCase;
  late SellViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(_FakeCreateParams());
    registerFallbackValue(_FakeUpdateParams());
  });

  setUp(() {
    repository = MockListingRepository();
    createUseCase = MockCreateListingUseCase();
    updateUseCase = MockUpdateListingUseCase();
    viewModel = SellViewModel(
      createListingUseCase: createUseCase,
      updateListingUseCase: updateUseCase,
      repository: repository,
      locationViewModel: LocationViewModel(initialValue: false),
    );
  });

  void fillBasics() {
    viewModel
      ..setTitle('Physics')
      ..setAuthor('Nelkon')
      ..setPrice(3000)
      ..setImageUrl('https://cdn.example.com/book.jpg');
  }

  group('validateForm', () {
    test('requires a class level', () {
      fillBasics();

      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.errorMessage, 'Class level is required');
      expect(viewModel.sellState, SellState.error);
    });

    test('requires a subject', () async {
      fillBasics();
      await viewModel.setClassLevel('cl-1');

      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.errorMessage, 'Subject is required');
    });

    test('school is optional', () async {
      fillBasics();
      await viewModel.setClassLevel('cl-1');
      await viewModel.setSubject('sub-1');

      expect(viewModel.validateForm(), isTrue);
    });
  });

  group('createListing', () {
    test('sends academic ids and the selected school', () async {
      when(
        () => createUseCase(any()),
      ).thenAnswer((_) async => Right(_listing(schoolId: 'sch-1')));
      fillBasics();
      await viewModel.setClassLevel('cl-1');
      await viewModel.setSubject('sub-1');
      await viewModel.setSchool(_molyko);

      await viewModel.createListing();

      final params =
          verify(() => createUseCase(captureAny())).captured.single
              as CreateListingParams;
      expect(params.classLevelId, 'cl-1');
      expect(params.subjectId, 'sub-1');
      expect(params.schoolId, 'sch-1');
      expect(viewModel.sellState, SellState.success);
    });

    test('does not call the use case when validation fails', () async {
      fillBasics();

      await viewModel.createListing();

      verifyNever(() => createUseCase(any()));
    });
  });

  group('applyDefaultSchool', () {
    test('pre-selects the profile school on a fresh form', () async {
      when(
        () => repository.getSchoolById('sch-1'),
      ).thenAnswer((_) async => const Right(_molyko));

      await viewModel.applyDefaultSchool('sch-1');

      expect(viewModel.selectedSchool, _molyko);
    });

    test('does nothing without a profile school', () async {
      await viewModel.applyDefaultSchool(null);

      verifyNever(() => repository.getSchoolById(any()));
      expect(viewModel.selectedSchool, isNull);
    });

    test('does not override a school the user already picked', () async {
      await viewModel.setSchool(_bilingual);

      await viewModel.applyDefaultSchool('sch-1');

      verifyNever(() => repository.getSchoolById(any()));
      expect(viewModel.selectedSchool, _bilingual);
    });

    test('a user pick made during the lookup wins', () async {
      when(() => repository.getSchoolById('sch-1')).thenAnswer((_) async {
        await viewModel.setSchool(_bilingual);
        return const Right(_molyko);
      });

      await viewModel.applyDefaultSchool('sch-1');

      expect(viewModel.selectedSchool, _bilingual);
    });

    test('is skipped while editing a listing', () async {
      viewModel.setEditingListing(_listing());
      await pumpEventQueue();

      await viewModel.applyDefaultSchool('sch-1');

      verifyNever(() => repository.getSchoolById(any()));
    });

    test('ignores lookup failures', () async {
      when(
        () => repository.getSchoolById('sch-1'),
      ).thenAnswer((_) async => const Left(ServerFailure(message: 'down')));

      await viewModel.applyDefaultSchool('sch-1');

      expect(viewModel.selectedSchool, isNull);
    });
  });

  group('editing', () {
    test('prefills academic fields from the listing', () async {
      when(
        () => repository.getSchoolById('sch-1'),
      ).thenAnswer((_) async => const Right(_molyko));

      viewModel.setEditingListing(_listing(schoolId: 'sch-1'));
      await pumpEventQueue();

      expect(viewModel.selectedClassLevelId, 'cl-1');
      expect(viewModel.selectedSubjectId, 'sub-1');
      expect(viewModel.selectedSchool, _molyko);
    });

    test('removing the school sends clearSchool', () async {
      when(
        () => repository.getSchoolById('sch-1'),
      ).thenAnswer((_) async => const Right(_molyko));
      when(
        () => updateUseCase(any()),
      ).thenAnswer((_) async => Right(_listing()));
      viewModel.setEditingListing(_listing(schoolId: 'sch-1'));
      await pumpEventQueue();

      await viewModel.setSchool(null);
      await viewModel.updateListing();

      final params =
          verify(() => updateUseCase(captureAny())).captured.single
              as UpdateListingParams;
      expect(params.schoolId, isNull);
      expect(params.clearSchool, isTrue);
    });

    test('keeping the school does not send clearSchool', () async {
      when(
        () => repository.getSchoolById('sch-1'),
      ).thenAnswer((_) async => const Right(_molyko));
      when(
        () => updateUseCase(any()),
      ).thenAnswer((_) async => Right(_listing(schoolId: 'sch-1')));
      viewModel.setEditingListing(_listing(schoolId: 'sch-1'));
      await pumpEventQueue();

      await viewModel.updateListing();

      final params =
          verify(() => updateUseCase(captureAny())).captured.single
              as UpdateListingParams;
      expect(params.schoolId, 'sch-1');
      expect(params.clearSchool, isFalse);
    });

    test('a listing without a school never sends clearSchool', () async {
      when(
        () => updateUseCase(any()),
      ).thenAnswer((_) async => Right(_listing()));
      viewModel.setEditingListing(_listing());
      await pumpEventQueue();

      await viewModel.updateListing();

      final params =
          verify(() => updateUseCase(captureAny())).captured.single
              as UpdateListingParams;
      expect(params.clearSchool, isFalse);
      verifyNever(() => repository.getSchoolById(any()));
    });
  });

  test('resetForm clears academic fields', () async {
    await viewModel.setClassLevel('cl-1');
    await viewModel.setSubject('sub-1');
    await viewModel.setSchool(_molyko);

    viewModel.resetForm();
    await pumpEventQueue();

    expect(viewModel.academicFilters.isEmpty, isTrue);
    expect(viewModel.selectedSchool, isNull);
  });
}
