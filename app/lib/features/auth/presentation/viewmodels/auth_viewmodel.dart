import 'package:flutter/material.dart';
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
    debugPrint('AuthViewModel: Initializing...');
    _initializeAuth();
  }

  /// Initializes the authentication state.
  Future<void> _initializeAuth() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      debugPrint(
        'AuthViewModel: [INIT] Checking current user (with 10s timeout)...',
      );

      final result = await getCurrentUserUseCase().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
            'AuthViewModel: [INIT] TIMEOUT occurred during auth check.',
          );
          throw Exception('Authentication check timed out');
        },
      );

      result.fold(
        (failure) {
          debugPrint(
            'AuthViewModel: [INIT] No current user found or error: ${failure.message}',
          );
          _authState = AuthState.unauthenticated;
          _currentUser = null;
        },
        (user) {
          debugPrint(
            'AuthViewModel: [INIT] User authenticated successfully: ${user.fullName}',
          );
          _authState = AuthState.authenticated;
          _currentUser = user;
        },
      );
    } catch (e) {
      debugPrint(
        'AuthViewModel: [INIT] Critical error during initialization: $e',
      );
      _authState = AuthState.unauthenticated;
      _currentUser = null;
    }

    debugPrint('AuthViewModel: [INIT] Setting up auth change listener...');
    _listenToAuthChanges();

    debugPrint('AuthViewModel: [INIT] Finalizing state: $_authState');
    notifyListeners();
  }

  /// Refreshes the current user data from the database.
  Future<void> refreshUser() async {
    final result = await getCurrentUserUseCase();
    result.fold(
      (failure) =>
          debugPrint('AuthViewModel: Refresh failed: ${failure.message}'),
      (user) {
        debugPrint('AuthViewModel: User refreshed: ${user.fullName}');
        _currentUser = user;
        notifyListeners();
      },
    );
  }

  /// Listens to authentication state changes from the repository.
  void _listenToAuthChanges() {
    repository.authStateChanges.listen(
      (user) {
        debugPrint(
          'AuthViewModel: [UPDATE] Auth state change detected. User: ${user?.fullName ?? 'null'}',
        );
        if (user != null) {
          debugPrint('AuthViewModel: [UPDATE] Switching to authenticated');
          _authState = AuthState.authenticated;
          _currentUser = user;
        } else {
          debugPrint('AuthViewModel: [UPDATE] Switching to unauthenticated');
          _authState = AuthState.unauthenticated;
          _currentUser = null;
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('AuthViewModel: [UPDATE] Stream error: $error');
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
