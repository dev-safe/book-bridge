import 'dart:io';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';

/// Data source for storage operations using Supabase Storage.
///
/// This class handles all file upload/download operations to/from Supabase Storage.
class SupabaseStorageDataSource {
  final SupabaseClient supabaseClient;

  SupabaseStorageDataSource({required this.supabaseClient});

  /// Uploads an image file to Supabase Storage.
  ///
  /// The image is uploaded to the 'books' bucket with a unique filename.
  /// Returns the public URL of the uploaded image.
  ///
  /// Throws [ServerException] if the upload fails.
  Future<String> uploadBookImage(File imageFile) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw AuthAppException(message: 'User not authenticated.');
      }

      // Generate a unique filename using timestamp and random string
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomString = _generateRandomString(8);
      // Store images in a subfolder named after the user's ID
      final filePath = '$userId/book_${timestamp}_$randomString.jpg';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload the file to the 'book_images' bucket using binary upload
      await Supabase.instance.client.storage
          .from('book_images')
          .uploadBinary(
            filePath, // Use filePath instead of fileName
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Return the public URL of the uploaded image
      final publicUrl = supabaseClient.storage
          .from('book_images')
          .getPublicUrl(filePath);
      return publicUrl;
    } on AuthAppException {
      rethrow;
    } on StorageException catch (e) {
      throw ServerException(message: 'Upload failed: ${e.message}');
    } catch (e) {
      throw ServerException(message: 'Upload failed: ${e.toString()}');
    }
  }

  /// Uploads a profile picture to Supabase Storage.
  ///
  /// The image is uploaded to the 'profiles' bucket with a unique filename.
  /// Returns the public URL of the uploaded image.
  ///
  /// Throws [ServerException] if the upload fails.
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw AuthAppException(message: 'User not authenticated.');
      }

      // We use a simple filename like avatar.jpg within the user's folder
      // so that it's easy to manage and replace.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$userId/avatar_$timestamp.jpg';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload the file to the 'profiles' bucket
      await supabaseClient.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Return the public URL
      final publicUrl = supabaseClient.storage
          .from('profiles')
          .getPublicUrl(filePath);
      return publicUrl;
    } on AuthAppException {
      rethrow;
    } on StorageException catch (e) {
      throw ServerException(
        message: 'Profile picture upload failed: ${e.message}',
      );
    } catch (e) {
      throw ServerException(
        message: 'Profile picture upload failed: ${e.toString()}',
      );
    }
  }

  /// Generates a random string of specified length.
  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Deletes an image from Supabase Storage.
  ///
  /// Throws [ServerException] if the deletion fails.
  Future<void> deleteBookImage(String imagePath) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw AuthAppException(message: 'User not authenticated.');
      }

      // Extract filename from the URL and construct the full path with userId
      final uri = Uri.parse(imagePath);
      final pathSegments = uri.pathSegments;
      // The last segment is the filename, we need to prepend the userId
      final fileName = pathSegments.last;
      final filePath = '$userId/$fileName';

      // Delete the file from the 'book_images' bucket
      await supabaseClient.storage.from('book_images').remove([filePath]);
    } on AuthAppException {
      rethrow;
    } on StorageException catch (e) {
      throw ServerException(message: 'Deletion failed: ${e.message}');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
