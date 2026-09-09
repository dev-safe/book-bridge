import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/features/auth/data/datasources/supabase_auth_data_source.dart';
import 'package:book_bridge/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/send_password_reset_email_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/update_user_usecase.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/core/local_db/local_database.dart';
import 'package:book_bridge/features/listings/data/datasources/local_listings_datasource.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_listings_data_source.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:book_bridge/features/listings/data/repositories/listing_repository_impl.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listings_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listing_details_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/delete_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_user_listings_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/search_listings_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/update_listing_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/listing_details_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/sell_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/profile_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/search_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/seller_profile_viewmodel.dart';
import 'package:book_bridge/features/notifications/data/datasources/supabase_notifications_data_source.dart';
import 'package:book_bridge/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:book_bridge/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:book_bridge/features/notifications/presentation/viewmodels/notifications_viewmodel.dart';
import 'package:book_bridge/features/notifications/data/services/push_notification_service.dart';
import 'package:book_bridge/features/payments/data/datasources/fapshi_data_source.dart';
import 'package:book_bridge/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:book_bridge/features/payments/domain/usecases/collect_payment_usecase.dart';
import 'package:book_bridge/features/payments/domain/usecases/get_payment_status_usecase.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/features/favorites/data/datasources/supabase_favorites_data_source.dart';
import 'package:book_bridge/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:book_bridge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:book_bridge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:book_bridge/features/favorites/domain/usecases/toggle_favorite_usecase.dart';
import 'package:book_bridge/features/favorites/domain/usecases/is_favorite_usecase.dart';
import 'package:book_bridge/features/favorites/presentation/viewmodels/favorites_viewmodel.dart';
import 'package:book_bridge/features/chat/data/datasources/supabase_chat_data_source.dart';
import 'package:book_bridge/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:book_bridge/features/chat/domain/repositories/chat_repository.dart';
import 'package:book_bridge/features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'package:book_bridge/core/presentation/viewmodels/theme_viewmodel.dart';
import 'package:book_bridge/features/transactions/data/datasources/supabase_transactions_data_source.dart';
import 'package:book_bridge/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:book_bridge/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:book_bridge/features/transactions/domain/usecases/get_user_transactions_usecase.dart';
import 'package:book_bridge/features/transactions/domain/usecases/get_transaction_by_external_ref_usecase.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/transaction_history_viewmodel.dart';
import 'package:book_bridge/features/reviews/data/datasources/supabase_reviews_data_source.dart';
import 'package:book_bridge/features/reviews/data/repositories/review_repository_impl.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';
import 'package:book_bridge/features/reviews/domain/usecases/create_review_usecase.dart';
import 'package:book_bridge/features/reviews/domain/usecases/get_user_reviews_usecase.dart';
import 'package:book_bridge/features/reviews/domain/usecases/has_reviewed_usecase.dart';
import 'package:book_bridge/features/reviews/presentation/viewmodels/review_viewmodel.dart';
import 'package:book_bridge/features/impact/data/datasources/supabase_impact_data_source.dart';
import 'package:book_bridge/features/impact/data/repositories/impact_repository_impl.dart';
import 'package:book_bridge/features/impact/domain/repositories/impact_repository.dart';
import 'package:book_bridge/features/impact/domain/usecases/get_platform_stats_usecase.dart';
import 'package:book_bridge/config/app_config.dart';
import 'package:book_bridge/features/safety/data/datasources/safety_remote_datasource.dart';
import 'package:book_bridge/features/safety/data/repositories/safety_repository_impl.dart';
import 'package:book_bridge/features/safety/domain/repositories/safety_repository.dart';
import 'package:book_bridge/features/safety/domain/usecases/get_campus_zones_usecase.dart';
import 'package:book_bridge/features/safety/presentation/viewmodels/safety_viewmodel.dart';

/// Service locator for dependency injection.
///
/// This singleton is responsible for managing the lifecycle of all
/// dependencies used throughout the application.
final getIt = GetIt.instance;

/// Initializes all dependencies for the application.
///
/// This function should be called in main.dart during app initialization
/// to set up the dependency injection container.
///
/// The dependencies are organized by layers:
/// - Core dependencies (error handling, usecases, theme)
/// - Feature-specific dependencies (auth, listings)
Future<void> setupDependencyInjection() async {
  // Initialize Supabase (must be done before other setup)
  final supabase = Supabase.instance.client;
  getIt.registerSingleton<SupabaseClient>(supabase);

  // Core Presentation
  getIt.registerLazySingleton<ThemeViewModel>(() => ThemeViewModel());

  // Auth Feature - Data Layer
  getIt.registerSingleton<SupabaseAuthDataSource>(
    SupabaseAuthDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(dataSource: getIt<SupabaseAuthDataSource>()),
  );

  // Auth Feature - Domain Layer (Use Cases)
  getIt.registerSingleton<SignUpUseCase>(
    SignUpUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<SignInUseCase>(
    SignInUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<SignOutUseCase>(
    SignOutUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<GetCurrentUserUseCase>(
    GetCurrentUserUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<SendPasswordResetEmailUseCase>(
    SendPasswordResetEmailUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<SignInWithGoogleUseCase>(
    SignInWithGoogleUseCase(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<UpdateUserUseCase>(
    UpdateUserUseCase(repository: getIt<AuthRepository>()),
  );

  // Auth Feature - Presentation Layer (ViewModels)
  getIt.registerSingleton<AuthViewModel>(
    AuthViewModel(
      signUpUseCase: getIt<SignUpUseCase>(),
      signInUseCase: getIt<SignInUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
      sendPasswordResetEmailUseCase: getIt<SendPasswordResetEmailUseCase>(),
      signInWithGoogleUseCase: getIt<SignInWithGoogleUseCase>(),
      repository: getIt<AuthRepository>(),
    ),
  );

  // Listings Feature - Data Layer
  getIt.registerSingleton<SupabaseStorageDataSource>(
    SupabaseStorageDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerSingleton<SupabaseListingsDataSource>(
    SupabaseListingsDataSource(
      supabaseClient: getIt<SupabaseClient>(),
      storageDataSource: getIt<SupabaseStorageDataSource>(),
    ),
  );

  // Local SQLite Cache setup
  final localDb = await LocalDatabase.instance.database;
  final localDataSource = LocalListingsDataSource(database: localDb);
  await localDataSource.clearExpiredCache(); // Housekeeping on startup

  getIt.registerSingleton<LocalListingsDataSource>(localDataSource);

  // Shared Preferences (used by Impact cache)
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  getIt.registerSingleton<ListingRepository>(
    ListingRepositoryImpl(
      dataSource: getIt<SupabaseListingsDataSource>(),
      localDataSource: getIt<LocalListingsDataSource>(),
    ),
  );

  // Listings Feature - Domain Layer (Use Cases)
  getIt.registerSingleton<GetListingsUseCase>(
    GetListingsUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<GetListingDetailsUseCase>(
    GetListingDetailsUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<CreateListingUseCase>(
    CreateListingUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<DeleteListingUseCase>(
    DeleteListingUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<GetUserListingsUseCase>(
    GetUserListingsUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<SearchListingsUseCase>(
    SearchListingsUseCase(repository: getIt<ListingRepository>()),
  );

  getIt.registerSingleton<UpdateListingUseCase>(
    UpdateListingUseCase(getIt<ListingRepository>()),
  );

  // Location Preference (must be loaded before ViewModels that depend on it)
  final locationViewModel = await LocationViewModel.load();
  getIt.registerSingleton<LocationViewModel>(locationViewModel);

  // Impact Feature
  getIt.registerLazySingleton<SupabaseImpactDataSource>(
    () => SupabaseImpactDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<ImpactRepository>(
    () => ImpactRepositoryImpl(
      dataSource: getIt<SupabaseImpactDataSource>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  getIt.registerLazySingleton<GetPlatformStatsUseCase>(
    () => GetPlatformStatsUseCase(repository: getIt<ImpactRepository>()),
  );

  // Listings Feature - Presentation Layer (ViewModels)
  getIt.registerSingleton<HomeViewModel>(
    HomeViewModel(
      getListingsUseCase: getIt<GetListingsUseCase>(),
      locationViewModel: getIt<LocationViewModel>(),
      listingRepository: getIt<ListingRepository>(),
      getPlatformStatsUseCase: getIt<GetPlatformStatsUseCase>(),
    ),
  );

  getIt.registerSingleton<ListingDetailsViewModel>(
    ListingDetailsViewModel(
      getListingDetailsUseCase: getIt<GetListingDetailsUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
    ),
  );

  getIt.registerSingleton<SellViewModel>(
    SellViewModel(
      createListingUseCase: getIt<CreateListingUseCase>(),
      updateListingUseCase: getIt<UpdateListingUseCase>(),
      repository: getIt<ListingRepository>(),
      locationViewModel: getIt<LocationViewModel>(),
    ),
  );

  getIt.registerSingleton<ProfileViewModel>(
    ProfileViewModel(
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
      getUserListingsUseCase: getIt<GetUserListingsUseCase>(),
      deleteListingUseCase: getIt<DeleteListingUseCase>(),
      updateUserUseCase: getIt<UpdateUserUseCase>(),
      storageDataSource: getIt<SupabaseStorageDataSource>(),
    ),
  );

  getIt.registerSingleton<SearchViewModel>(
    SearchViewModel(
      searchListingsUseCase: getIt<SearchListingsUseCase>(),
      repository: getIt<ListingRepository>(),
    ),
  );

  getIt.registerFactory<SellerProfileViewModel>(
    () => SellerProfileViewModel(
      authRepository: getIt<AuthRepository>(),
      listingRepository: getIt<ListingRepository>(),
      reviewRepository: getIt<ReviewRepository>(),
    ),
  );

  // Notifications Feature
  getIt.registerSingleton<SupabaseNotificationsDataSource>(
    SupabaseNotificationsDataSource(getIt<SupabaseClient>()),
  );

  getIt.registerSingleton<NotificationsRepository>(
    NotificationsRepositoryImpl(getIt<SupabaseNotificationsDataSource>()),
  );

  getIt.registerLazySingleton<NotificationsViewModel>(
    () => NotificationsViewModel(getIt<NotificationsRepository>()),
  );

  getIt.registerSingleton<PushNotificationService>(
    PushNotificationService(getIt<AuthRepository>()),
  );

  // Payments Feature
  getIt.registerLazySingleton<FapshiDataSource>(
    () => FapshiDataSource(
      apiUser: AppConfig.fapshiApiUser,
      apiKey: AppConfig.fapshiApiKey,
      baseUrl: AppConfig.fapshiBaseUrl,
    ),
  );

  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(getIt<FapshiDataSource>()),
  );

  getIt.registerLazySingleton<CollectPaymentUseCase>(
    () => CollectPaymentUseCase(repository: getIt<PaymentRepository>()),
  );

  getIt.registerLazySingleton<GetPaymentStatusUseCase>(
    () => GetPaymentStatusUseCase(repository: getIt<PaymentRepository>()),
  );

  getIt.registerFactory<PaymentViewModel>(
    () => PaymentViewModel(
      collectPaymentUseCase: getIt<CollectPaymentUseCase>(),
      getPaymentStatusUseCase: getIt<GetPaymentStatusUseCase>(),
    ),
  );

  // Favorites Feature
  getIt.registerLazySingleton<SupabaseFavoritesDataSource>(
    () => SupabaseFavoritesDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(
      dataSource: getIt<SupabaseFavoritesDataSource>(),
    ),
  );

  getIt.registerLazySingleton<GetFavoritesUseCase>(
    () => GetFavoritesUseCase(getIt<FavoritesRepository>()),
  );

  getIt.registerLazySingleton<ToggleFavoriteUseCase>(
    () => ToggleFavoriteUseCase(getIt<FavoritesRepository>()),
  );

  getIt.registerLazySingleton<IsFavoriteUseCase>(
    () => IsFavoriteUseCase(getIt<FavoritesRepository>()),
  );

  getIt.registerLazySingleton<FavoritesViewModel>(
    () => FavoritesViewModel(
      getFavoritesUseCase: getIt<GetFavoritesUseCase>(),
      toggleFavoriteUseCase: getIt<ToggleFavoriteUseCase>(),
      isFavoriteUseCase: getIt<IsFavoriteUseCase>(),
      authRepository: getIt<AuthRepository>(),
    ),
  );

  // Chat Feature
  getIt.registerLazySingleton<SupabaseChatDataSource>(
    () => SupabaseChatDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(dataSource: getIt<SupabaseChatDataSource>()),
  );

  getIt.registerFactory<ChatViewModel>(
    () => ChatViewModel(repository: getIt<ChatRepository>()),
  );

  // Transaction History
  getIt.registerLazySingleton<SupabaseTransactionsDataSource>(
    () =>
        SupabaseTransactionsDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      dataSource: getIt<SupabaseTransactionsDataSource>(),
    ),
  );

  getIt.registerLazySingleton<GetUserTransactionsUseCase>(
    () => GetUserTransactionsUseCase(getIt<TransactionRepository>()),
  );

  getIt.registerLazySingleton<GetTransactionByExternalRefUseCase>(
    () => GetTransactionByExternalRefUseCase(getIt<TransactionRepository>()),
  );

  getIt.registerFactory<TransactionHistoryViewModel>(
    () => TransactionHistoryViewModel(
      useCase: getIt<GetUserTransactionsUseCase>(),
      repository: getIt<TransactionRepository>(),
    ),
  );

  // Reviews Feature
  getIt.registerLazySingleton<SupabaseReviewsDataSource>(
    () => SupabaseReviewsDataSource(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(getIt<SupabaseReviewsDataSource>()),
  );

  getIt.registerLazySingleton<CreateReviewUseCase>(
    () => CreateReviewUseCase(getIt<ReviewRepository>()),
  );

  getIt.registerLazySingleton<GetUserReviewsUseCase>(
    () => GetUserReviewsUseCase(getIt<ReviewRepository>()),
  );

  getIt.registerLazySingleton<HasReviewedUseCase>(
    () => HasReviewedUseCase(getIt<ReviewRepository>()),
  );

  getIt.registerFactory<ReviewViewModel>(
    () => ReviewViewModel(
      createReviewUseCase: getIt<CreateReviewUseCase>(),
      hasReviewedUseCase: getIt<HasReviewedUseCase>(),
      getTransactionByExternalRefUseCase:
          getIt<GetTransactionByExternalRefUseCase>(),
    ),
  );

  // Safety Feature
  getIt.registerLazySingleton<SafetyRemoteDataSource>(
    () => SafetyRemoteDataSource(supabaseClient: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<SafetyRepository>(
    () =>
        SafetyRepositoryImpl(remoteDataSource: getIt<SafetyRemoteDataSource>()),
  );

  getIt.registerLazySingleton<GetCampusZonesUseCase>(
    () => GetCampusZonesUseCase(getIt<SafetyRepository>()),
  );

  getIt.registerFactory<SafetyViewModel>(
    () =>
        SafetyViewModel(getCampusZonesUseCase: getIt<GetCampusZonesUseCase>()),
  );
}
