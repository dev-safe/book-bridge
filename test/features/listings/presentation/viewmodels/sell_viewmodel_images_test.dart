import 'dart:io';

import 'package:book_bridge/core/error/failures.dart';
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

const _a = 'https://cdn.example.com/a.jpg';
const _b = 'https://cdn.example.com/b.jpg';
const _c = 'https://cdn.example.com/c.jpg';
const _d = 'https://cdn.example.com/d.jpg';

Listing _listing({String imageUrl = _a, List<String> imageUrls = const []}) =>
    Listing(
      id: 'lst-1',
      title: 'Physics',
      author: 'Nelkon',
      priceFcfa: 3000,
      condition: BookCondition.good,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      description: '',
      sellerId: 'seller-1',
      status: 'available',
      createdAt: DateTime(2026, 10, 1),
      classLevelId: 'cl-1',
      subjectId: 'sub-1',
    );

void main() {
  late MockCreateListingUseCase createUseCase;
  late MockUpdateListingUseCase updateUseCase;
  late MockListingRepository repository;
  late SellViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(_FakeCreateParams());
    registerFallbackValue(_FakeUpdateParams());
    registerFallbackValue(File(''));
  });

  setUp(() {
    createUseCase = MockCreateListingUseCase();
    updateUseCase = MockUpdateListingUseCase();
    repository = MockListingRepository();
    viewModel = SellViewModel(
      createListingUseCase: createUseCase,
      updateListingUseCase: updateUseCase,
      repository: repository,
      locationViewModel: LocationViewModel(initialValue: false),
    );
  });

  Future<void> fillRequired() async {
    viewModel
      ..setTitle('Physics')
      ..setAuthor('Nelkon')
      ..setPrice(3000);
    await viewModel.setClassLevel('cl-1');
    await viewModel.setSubject('sub-1');
  }

  group('photo list', () {
    test('starts empty with no cover', () {
      expect(viewModel.imageUrls, isEmpty);
      expect(viewModel.imageUrl, isNull);
      expect(viewModel.canAddImage, isTrue);
    });

    test('addImageUrl appends and the first photo is the cover', () {
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl(_b);

      expect(viewModel.imageUrls, [_a, _b]);
      expect(viewModel.imageUrl, _a);
    });

    test('caps photos at Listing.maxImages', () {
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl(_b)
        ..addImageUrl(_c)
        ..addImageUrl(_d);

      expect(viewModel.imageUrls, [_a, _b, _c]);
      expect(viewModel.imageUrls.length, Listing.maxImages);
      expect(viewModel.canAddImage, isFalse);
    });

    test('removing the cover promotes the next photo', () {
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl(_b)
        ..removeImageAt(0);

      expect(viewModel.imageUrls, [_b]);
      expect(viewModel.imageUrl, _b);
    });

    test('removeImageAt ignores out-of-range indexes', () {
      viewModel
        ..addImageUrl(_a)
        ..removeImageAt(5)
        ..removeImageAt(-1);

      expect(viewModel.imageUrls, [_a]);
    });

    test('setCoverAt moves the photo to the front, keeping the rest', () {
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl(_b)
        ..addImageUrl(_c)
        ..setCoverAt(2);

      expect(viewModel.imageUrls, [_c, _a, _b]);
      expect(viewModel.imageUrl, _c);
    });

    test('setImageUrl replaces only the cover', () {
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl(_b)
        ..setImageUrl(_c);

      expect(viewModel.imageUrls, [_c, _b]);
    });

    test('notifies listeners on change', () {
      var calls = 0;
      viewModel.addListener(() => calls++);

      viewModel
        ..addImageUrl(_a)
        ..setCoverAt(0)
        ..removeImageAt(0);

      expect(calls, 2);
    });
  });

  group('validateForm', () {
    test('requires at least one photo', () async {
      await fillRequired();

      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.errorMessage, 'Book image is required');
    });

    test('rejects photos that have not finished uploading', () async {
      await fillRequired();
      viewModel
        ..addImageUrl(_a)
        ..addImageUrl('/data/local/b.jpg');

      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.errorMessage, 'Please wait for image to upload');
    });
  });

  group('editing', () {
    test('prefills every photo from the listing', () {
      viewModel.setEditingListing(_listing(imageUrls: const [_a, _b]));

      expect(viewModel.imageUrls, [_a, _b]);
    });

    test('prefills the cover alone for legacy listings', () {
      viewModel.setEditingListing(_listing());

      expect(viewModel.imageUrls, [_a]);
    });

    test('updateListing sends the full photo list', () async {
      when(
        () => updateUseCase(any()),
      ).thenAnswer((_) async => Right(_listing()));
      viewModel
        ..setEditingListing(_listing(imageUrls: const [_a, _b]))
        ..setCoverAt(1);
      await viewModel.setClassLevel('cl-1');
      await viewModel.setSubject('sub-1');

      await viewModel.updateListing();

      final params =
          verify(() => updateUseCase(captureAny())).captured.single
              as UpdateListingParams;
      expect(params.imageUrl, _b);
      expect(params.imageUrls, [_b, _a]);
    });
  });

  test('createListing sends the cover and all photos', () async {
    when(() => createUseCase(any())).thenAnswer((_) async => Right(_listing()));
    await fillRequired();
    viewModel
      ..addImageUrl(_a)
      ..addImageUrl(_b);

    await viewModel.createListing();

    final params =
        verify(() => createUseCase(captureAny())).captured.single
            as CreateListingParams;
    expect(params.imageUrl, _a);
    expect(params.imageUrls, [_a, _b]);
  });

  test('reset clears photos', () {
    viewModel
      ..addImageUrl(_a)
      ..resetForm();

    expect(viewModel.imageUrls, isEmpty);
  });

  group('addImageFiles (multi-select)', () {
    final files = [for (final n in 'wxyz'.split('')) File('/tmp/$n.jpg')];

    test('uploads selected photos in order up to the cap', () async {
      final urls = {
        files[0].path: _a,
        files[1].path: _b,
        files[2].path: _c,
        files[3].path: _d,
      };
      when(() => repository.uploadBookImage(any())).thenAnswer(
        (inv) async =>
            Right(urls[(inv.positionalArguments.first as File).path]!),
      );

      await viewModel.addImageFiles(files);

      expect(viewModel.imageUrls, [_a, _b, _c]);
      expect(viewModel.sellState, SellState.initial);
      verifyNever(() => repository.uploadBookImage(files[3]));
    });

    test('fills only the remaining slots', () async {
      viewModel.addImageUrl(_a);
      when(
        () => repository.uploadBookImage(any()),
      ).thenAnswer((_) async => const Right(_b));

      await viewModel.addImageFiles(files);

      expect(viewModel.imageUrls, [_a, _b, _b]);
      verify(() => repository.uploadBookImage(any())).called(2);
    });

    test('stops at the first failed upload', () async {
      when(
        () => repository.uploadBookImage(files[0]),
      ).thenAnswer((_) async => const Right(_a));
      when(
        () => repository.uploadBookImage(files[1]),
      ).thenAnswer((_) async => const Left(ServerFailure(message: 'network')));

      await viewModel.addImageFiles(files);

      expect(viewModel.imageUrls, [_a]);
      expect(viewModel.sellState, SellState.error);
      verifyNever(() => repository.uploadBookImage(files[2]));
    });

    test('does nothing for an empty selection', () async {
      await viewModel.addImageFiles(const []);

      expect(viewModel.imageUrls, isEmpty);
      verifyNever(() => repository.uploadBookImage(any()));
    });
  });
}
