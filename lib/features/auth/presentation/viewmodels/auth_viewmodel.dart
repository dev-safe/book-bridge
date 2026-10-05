import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/send_password_reset_email_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Represents the different authentication states.
enum AuthState { initial, loading, authenticated, unauthenticated, error }

enum AuthStatus { none, passwordResetSent }

/// ViewModel for managing authentication state and operations.
///
/// This ChangeNotifier manages the authentication flow, including sign-up,
/// sign-in, sign-out, and session management.
class AuthViewModel extends ChangeNotifier {
  final SignUpUseCase signUpUseCase;
  final SignInUseCase signInUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SendPasswordResetEmailUseCase sendPasswordResetEmailUseCase;
  final SignInWithGoogleUseCase signInWithGoogleUseCase;
  final AuthRepository repository;

  // State
  AuthState _authState = AuthState.initial;
  AuthStatus _authStatus = AuthStatus.none;
  User? _currentUser;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  AuthState get authState => _authState;
  AuthStatus get authStatus => _authStatus;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isAuthenticated =>
      _authState == AuthState.authenticated && _currentUser != null;

  AuthViewModel({
    required this.signUpUseCase,
    required this.signInUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.sendPasswordResetEmailUseCase,
    required this.signInWithGoogleUseCase,
    required this.repository,
  }) {
    _initializeAuth();
  }

  /// Initializes the authentication state.
  Future<void> _initializeAuth() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      final result = await getCurrentUserUseCase().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Authentication check timed out');
        },
      );

      result.fold(
        (failure) {
          _authState = AuthState.unauthenticated;
          _currentUser = null;
        },
        (user) {
          _authState = AuthState.authenticated;
          _currentUser = user;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AuthViewModel: init failed: $e');
      _authState = AuthState.unauthenticated;
      _currentUser = null;
    }

    _listenToAuthChanges();

    notifyListeners();
  }

  /// Refreshes the current user data from the database.
  Future<void> refreshUser() async {
    final result = await getCurrentUserUseCase();
    result.fold(
      (failure) {
        if (kDebugMode) debugPrint('AuthViewModel: refresh failed');
      },
      (user) {
        _currentUser = user;
        notifyListeners();
      },
    );
  }

  /// Listens to authentication state changes from the repository.
  void _listenToAuthChanges() {
    repository.authStateChanges.listen(
      (user) {
        if (user != null) {
          _authState = AuthState.authenticated;
          _currentUser = user;
        } else {
          _authState = AuthState.unauthenticated;
          _currentUser = null;
        }
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) debugPrint('AuthViewModel: auth stream error: $error');
      },
    );
  }

  /// Performs user sign-up with email, password, and full name.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String locality,
    required String whatsappNumber,
  }) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final params = SignUpParams(
      email: email,
      password: password,
      fullName: fullName,
      locality: locality,
      whatsappNumber: whatsappNumber,
    );

    final result = await signUpUseCase(params);
    result.fold(
      (failure) {
        _authState = AuthState.error;
        _errorMessage = failure.message;
        _currentUser = null;
      },
      (user) {
        _authState = AuthState.authenticated;
        _currentUser = user;
        _errorMessage = null;
      },
    );
    notifyListeners();
  }

  /// Performs user sign-in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final params = SignInParams(email: email, password: password);

    final result = await signInUseCase(params);
    result.fold(
      (failure) {
        _authState = AuthState.error;
        _errorMessage = failure.message;
        _currentUser = null;
      },
      (user) {
        _authState = AuthState.authenticated;
        _currentUser = user;
        _errorMessage = null;
      },
    );
    notifyListeners();
  }

  /// Performs user sign-in with Google.
  Future<void> signInWithGoogle() async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await signInWithGoogleUseCase();
    result.fold(
      (failure) {
        _authState = AuthState.error;
        _errorMessage = failure.message;
        _currentUser = null;
      },
      (user) {
        _authState = AuthState.authenticated;
        _currentUser = user;
        _errorMessage = null;
      },
    );
    notifyListeners();
  }

  /// Checks if the current user profile is complete.
  ///
  /// Returns true if Locality and WhatsApp Number are filled.
  bool get isProfileComplete {
    if (_currentUser == null) return false;
    return (_currentUser!.locality?.isNotEmpty ?? false) &&
        (_currentUser!.whatsappNumber?.isNotEmpty ?? false);
  }

  /// Whether the current user has made the 18+/guardian self-declaration.
  bool get hasAgeDeclaration => _currentUser?.hasAgeDeclaration ?? false;

  /// Records the age self-declaration (`adult` or `guardian`).
  ///
  /// Does not touch [authState] so the router does not react mid-request.
  /// Returns true on success; on failure sets [errorMessage].
  Future<bool> declareAge(String choice) async {
    _errorMessage = null;
    final result = await repository.declareAge(choice);
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }
    final user = _currentUser;
    if (user != null) {
      _currentUser = user.copyWith(
        ageDeclaration: choice,
        ageDeclaredAt: DateTime.now(),
      );
    }
    notifyListeners();
    await refreshUser();
    return true;
  }

  bool _isSubmittingId = false;

  /// Whether an ID verification submission is in flight.
  bool get isSubmittingId => _isSubmittingId;

  /// Whether the current user's ID has been approved by an admin.
  bool get isIdVerified => _currentUser?.isIdVerified ?? false;

  /// Uploads ID photos and submits them for admin review.
  ///
  /// Does not touch [authState] so the router does not react mid-request.
  /// Returns true on success; on failure sets [errorMessage].
  Future<bool> submitIdVerification({
    required DateTime dateOfBirth,
    required List<Uint8List> documents,
    String? guardianPhone,
  }) async {
    _errorMessage = null;
    _isSubmittingId = true;
    notifyListeners();
    final result = await repository.submitIdVerification(
      dateOfBirth: dateOfBirth,
      documents: documents,
      guardianPhone: guardianPhone,
    );
    _isSubmittingId = false;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }
    final user = _currentUser;
    if (user != null) {
      _currentUser = user.copyWith(
        idVerificationStatus: 'pending',
        dateOfBirth: dateOfBirth,
      );
    }
    notifyListeners();
    await refreshUser();
    return true;
  }

  /// Performs user sign-out.
  Future<void> signOut() async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await signOutUseCase();
    result.fold(
      (failure) {
        _authState = AuthState.error;
        _errorMessage = failure.message;
      },
      (_) {
        _authState = AuthState.unauthenticated;
        _currentUser = null;
        _errorMessage = null;
      },
    );
    notifyListeners();
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final result = await sendPasswordResetEmailUseCase(email);
    result.fold(
      (failure) {
        _authState = AuthState.error;
        _errorMessage = failure.message;
      },
      (_) {
        _authState = AuthState.unauthenticated; // Stay on the same screen
        _authStatus = AuthStatus.passwordResetSent;
        _successMessage = 'Password reset link sent to your email.';
      },
    );
    notifyListeners();
  }

  /// Clears the error message.
  void clearError() {
    _errorMessage = null;
    if (_authState == AuthState.error) {
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Clears status messages.
  void clearStatus() {
    _errorMessage = null;
    _successMessage = null;
    _authStatus = AuthStatus.none;
    // Don't notify listeners here to avoid unnecessary rebuilds if no message was there
  }
}
