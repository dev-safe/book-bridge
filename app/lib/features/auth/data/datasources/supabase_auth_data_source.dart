import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/auth/data/models/user_model.dart';

/// Data source for authentication operations using Supabase.
///
/// This class handles all authentication-related API calls to Supabase,
/// including sign-up, sign-in, sign-out, and fetching user profiles.
class SupabaseAuthDataSource {
  final SupabaseClient supabaseClient;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
  );

  SupabaseAuthDataSource({required this.supabaseClient});

  /// Signs up a new user with email and password.
  ///
  /// Throws [AuthAppException] if the sign-up fails.
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String locality,
    required String whatsappNumber,
  }) async {
    try {
      // Sign up with Supabase Auth
      final authResponse = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'locality': locality,
          'whatsapp_number': whatsappNumber,
        },
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw AuthAppException(message: 'Failed to create user');
      }

      // Profile is created automatically by database trigger via metadata.
      // We poll for the profile to ensure the trigger has completed.
      return await _waitForProfileCreation(userId);
    } on AuthException catch (e) {
      if (e.statusCode == '429' ||
          e.message.contains('rate limit') ||
          e.code == 'over_email_send_rate_limit') {
        throw AuthAppException(
          message:
              'Too many attempts. Please check your email inbox or wait a minute before trying again.',
        );
      }
      throw AuthAppException(message: e.message);
    } on AuthAppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Signs in a user with email and password.
  ///
  /// Throws [AuthAppException] if the sign-in fails.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw AuthAppException(message: 'Failed to sign in');
      }

      // Fetch and return the user profile
      return _fetchUserProfile(userId);
    } on AuthException catch (e) {
      throw AuthAppException(message: e.message);
    } on AuthAppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw AuthAppException(message: e.toString());
    }
  }

  /// Signs in a user using Google Sign-In.
  ///
  /// This method handles the OAuth2 flow with Google and then
  /// authenticates with Supabase using the ID token.
  Future<UserModel> signInWithGoogle() async {
    try {
      // 1. Clear previous Google sign-in state to force account selection if needed
      await _googleSignIn.signOut();

      // 2. Start the sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthAppException(message: 'Google Sign-In was cancelled');
      }

      // 3. Get the authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw AuthAppException(message: 'No ID Token found.');
      }

      // 4. Sign in to Supabase with the ID token
      final authResponse = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw AuthAppException(message: 'Failed to sign in with Google');
      }

      // 5. Fetch and return the user profile
      // If it's a new user, the database trigger should have created the profile
      try {
        return await _fetchUserProfile(userId);
      } catch (e) {
        // If profile doesn't exist yet, wait for creation (trigger might be slow)
        return await _waitForProfileCreation(userId);
      }
    } on AuthException catch (e) {
      throw AuthAppException(message: e.message);
    } catch (e) {
      if (e is AuthAppException) rethrow;
      throw AuthAppException(message: e.toString());
    }
  }

  /// Signs out the currently authenticated user.
  ///
  /// Throws [AuthAppException] if the sign-out fails.
  Future<void> signOut() async {
    try {
      await Future.wait([
        supabaseClient.auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw AuthAppException(message: 'Failed to sign out: ${e.toString()}');
    }
  }

  /// Retrieves the profile of the currently authenticated user.
  ///
  /// Throws [UserNotFoundException] if no user is authenticated.
  /// Throws [NotFoundException] if the user profile does not exist.
  Future<UserModel> getCurrentUserProfile() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw UserNotFoundException(
          message: 'No user is currently authenticated',
        );
      }

      return _fetchUserProfile(user.id);
    } on UserNotFoundException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Sends a password reset email to the given email address.
  ///
  /// Throws [AuthAppException] if the operation fails.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await supabaseClient.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthAppException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Streams authentication state changes.
  ///
  /// Emits [UserModel] when a user signs in/up and null when they sign out.
  Stream<UserModel?> authStateChanges() {
    return supabaseClient.auth.onAuthStateChange.asyncMap((event) async {
      if (event.session?.user != null) {
        try {
          return await _fetchUserProfile(event.session!.user.id);
        } catch (e) {
          return null;
        }
      }
      return null;
    });
  }

  /// Fetches a user's profile from the profiles table.
  ///
  /// Private helper method used internally.
  Future<UserModel> _fetchUserProfile(String userId) async {
    try {
      final response = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      // Get the user from auth - this might be null immediately after sign-up
      // so we'll use the userId and email from the response if needed
      final user = supabaseClient.auth.currentUser;

      // Combine auth user data with profile data
      final profileData = response;
      profileData['id'] = userId;
      profileData['email'] = user?.email ?? response['email'] ?? '';
      profileData['created_at'] = user?.createdAt is DateTime
          ? (user!.createdAt as DateTime).toIso8601String()
          : response['created_at']?.toString() ??
                DateTime.now().toIso8601String();

      return UserModel.fromJson(profileData);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException(message: 'User profile not found');
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Polls for the user profile creation (waits for DB trigger).
  Future<UserModel> _waitForProfileCreation(String userId) async {
    int attempts = 0;
    while (attempts < 5) {
      try {
        return await _fetchUserProfile(userId);
      } catch (e) {
        // If it's a "Not Found" error (PGRST116 handled in _fetchUserProfile as NotFoundException), wait and retry
        if (e is NotFoundException ||
            (e is ServerException && e.message.contains('not found'))) {
          attempts++;
          if (attempts >= 5) rethrow; // Give up after 5 attempts
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          rethrow; // Propagate other errors immediately
        }
      }
    }
    // If we reach here, it means we've exhausted all attempts
    throw ServerException(message: 'Profile creation timed out');
  }

  /// Updates a user's profile data.
  Future<UserModel> updateUser(UserModel userToUpdate) async {
    try {
      final response = await supabaseClient
          .from('profiles')
          .update({
            'full_name': userToUpdate.fullName,
            'locality': userToUpdate.locality,
            'whatsapp_number': userToUpdate.whatsappNumber,
            'avatar_url': userToUpdate.avatarUrl,
          })
          .eq('id', userToUpdate.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Updates the FCM token for a user.
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await supabaseClient
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Retrieves user profile by ID.
  Future<UserModel> getUserById(String userId) async {
    return _fetchUserProfile(userId);
  }
}
