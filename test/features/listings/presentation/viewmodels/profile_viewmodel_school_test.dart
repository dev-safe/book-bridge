import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/update_user_usecase.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:book_bridge/features/listings/domain/usecases/delete_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_user_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/profile_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockGetUserListingsUseCase extends Mock
    implements GetUserListingsUseCase {}

class MockDeleteListingUseCase extends Mock implements DeleteListingUseCase {}

class MockUpdateUserUseCase extends Mock implements UpdateUserUseCase {}

class MockStorageDataSource extends Mock implements SupabaseStorageDataSource {}

class FakeUser extends Fake implements User {}

class FakeGetUserListingsParams extends Fake implements GetUserListingsParams {}

void main() {
  late MockGetCurrentUserUseCase getCurrentUser;
  late MockGetUserListingsUseCase getUserListings;
  late MockUpdateUserUseCase updateUser;
  late ProfileViewModel viewModel;

  final user = User(
    id: 'user-1',
    email: 'student@example.com',
    fullName: 'Test Student',
    schoolId: 'sch-1',
    createdAt: DateTime(2026, 10, 1),
  );

  setUpAll(() {
    registerFallbackValue(FakeUser());
    registerFallbackValue(FakeGetUserListingsParams());
  });

  setUp(() async {
    getCurrentUser = MockGetCurrentUserUseCase();
    getUserListings = MockGetUserListingsUseCase();
    updateUser = MockUpdateUserUseCase();
    when(() => getCurrentUser()).thenAnswer((_) async => right(user));
    when(() => getUserListings(any())).thenAnswer((_) async => right([]));
    when(
      () => updateUser(any()),
    ).thenAnswer((inv) async => right(inv.positionalArguments.first as User));

    viewModel = ProfileViewModel(
      getCurrentUserUseCase: getCurrentUser,
      getUserListingsUseCase: getUserListings,
      deleteListingUseCase: MockDeleteListingUseCase(),
      updateUserUseCase: updateUser,
      storageDataSource: MockStorageDataSource(),
    );
    await viewModel.loadProfile();
    await pumpEventQueue();
  });

  User capturedUpdate() =>
      verify(() => updateUser(captureAny())).captured.single as User;

  test('updateUser without school args keeps the current school', () async {
    await viewModel.updateUser(fullName: 'New Name');

    final sent = capturedUpdate();
    expect(sent.schoolId, 'sch-1');
    expect(sent.fullName, 'New Name');
    expect(viewModel.currentUser?.schoolId, 'sch-1');
  });

  test('updateUser with schoolId switches the school', () async {
    await viewModel.updateUser(schoolId: 'sch-2');

    expect(capturedUpdate().schoolId, 'sch-2');
    expect(viewModel.currentUser?.schoolId, 'sch-2');
  });

  test('updateUser with clearSchool removes the school', () async {
    await viewModel.updateUser(clearSchool: true);

    expect(capturedUpdate().schoolId, isNull);
    expect(viewModel.currentUser?.schoolId, isNull);
    expect(viewModel.profileState, ProfileState.loaded);
  });
}
