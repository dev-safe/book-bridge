import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/seller_profile_viewmodel.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockListingRepository extends Mock implements ListingRepository {}

class MockReviewRepository extends Mock implements ReviewRepository {}

void main() {
  late SellerProfileViewModel viewModel;
  late MockAuthRepository mockAuthRepository;
  late MockListingRepository mockListingRepository;
  late MockReviewRepository mockReviewRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockListingRepository = MockListingRepository();
    mockReviewRepository = MockReviewRepository();
    viewModel = SellerProfileViewModel(
      authRepository: mockAuthRepository,
      listingRepository: mockListingRepository,
      reviewRepository: mockReviewRepository,
    );
  });

  const tUserId = 'user-123';
  final tUser = User(
    id: tUserId,
    email: 'test@example.com',
    fullName: 'Test User',
    createdAt: DateTime.now(),
  );

  final tListings = [
    Listing(
      id: 'listing-1',
      sellerId: tUserId,
      title: 'Listing 1',
      author: 'Author 1',
      description: 'Desc 1',
      priceFcfa: 1000,
      condition: BookCondition.good,
      category: 'Academic',
      status: 'available',
      imageUrl: '',
      createdAt: DateTime.now(),
    ),
  ];

  group('SellerProfileViewModel', () {
    test('should fetch seller data and listings successfully', () async {
      // Arrange
      when(
        () => mockAuthRepository.getUserById(tUserId),
      ).thenAnswer((_) async => Right(tUser));
      when(
        () => mockListingRepository.getListingsBySeller(tUserId),
      ).thenAnswer((_) async => Right(tListings));
      when(
        () => mockReviewRepository.getUserReviews(tUserId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      await viewModel.loadSellerProfile(tUserId);

      // Assert
      expect(viewModel.isLoading, false);
      expect(viewModel.seller, tUser);
      expect(viewModel.listings, tListings);
      expect(viewModel.error, null);
      verify(() => mockAuthRepository.getUserById(tUserId)).called(1);
      verify(
        () => mockListingRepository.getListingsBySeller(tUserId),
      ).called(1);
    });

    test('should handle error when fetching seller profile fails', () async {
      // Arrange
      when(
        () => mockAuthRepository.getUserById(tUserId),
      ).thenAnswer((_) async => const Left(ServerFailure(message: 'Error')));

      // Act
      await viewModel.loadSellerProfile(tUserId);

      // Assert
      expect(viewModel.isLoading, false);
      expect(viewModel.error, 'Error');
    });
  });
}
