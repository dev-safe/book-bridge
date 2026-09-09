import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/listings/presentation/screens/seller_profile_screen.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/seller_profile_viewmodel.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockSellerProfileViewModel extends Mock
    implements SellerProfileViewModel {}

void main() {
  late MockSellerProfileViewModel mockViewModel;

  setUpAll(() {
    registerFallbackValue(const Locale('en'));
  });

  setUp(() {
    mockViewModel = MockSellerProfileViewModel();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ChangeNotifierProvider<SellerProfileViewModel>.value(
        value: mockViewModel,
        child: const SellerProfileScreen(userId: 'user-123'),
      ),
    );
  }

  testWidgets('should display loading indicator when state is loading', (
    tester,
  ) async {
    // Arrange
    when(() => mockViewModel.isLoading).thenReturn(true);
    when(() => mockViewModel.loadSellerProfile(any())).thenAnswer((_) async {});

    // Act
    await tester.pumpWidget(createWidgetUnderTest());

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should display seller full name when data is loaded', (
    tester,
  ) async {
    // Arrange
    final tUser = User(
      id: 'user-123',
      email: 'seller@test.com',
      fullName: 'John Seller',
      locality: 'Yaounde',
      createdAt: DateTime.now(),
    );
    when(() => mockViewModel.isLoading).thenReturn(false);
    when(() => mockViewModel.seller).thenReturn(tUser);
    when(() => mockViewModel.listings).thenReturn([]);
    when(() => mockViewModel.reviews).thenReturn([]);
    when(() => mockViewModel.error).thenReturn(null);
    when(() => mockViewModel.averageRating).thenReturn(4.5);
    when(() => mockViewModel.loadSellerProfile(any())).thenAnswer((_) async {});

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Start load
    await tester.pump(); // Build with data

    // Assert
    expect(find.text('John Seller'), findsOneWidget);
    expect(find.text('Yaounde'), findsOneWidget);
  });

  testWidgets('should display error message when loading fails', (
    tester,
  ) async {
    // Arrange
    when(() => mockViewModel.isLoading).thenReturn(false);
    when(() => mockViewModel.error).thenReturn('Failed to load profile');
    when(() => mockViewModel.loadSellerProfile(any())).thenAnswer((_) async {});

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Assert
    expect(find.text('Failed to load profile'), findsOneWidget);
  });
}
