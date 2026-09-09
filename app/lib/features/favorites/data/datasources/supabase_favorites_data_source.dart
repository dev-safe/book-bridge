import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/data/models/listing_model.dart';

class SupabaseFavoritesDataSource {
  final SupabaseClient supabaseClient;

  SupabaseFavoritesDataSource({required this.supabaseClient});

  Future<List<ListingModel>> getFavorites(String userId) async {
    try {
      final response = await supabaseClient
          .from('wishlists')
          .select('*, listings(*, profiles:seller_id(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final favorites = (response as List<dynamic>).map((item) {
        final listingJson = item['listings'] as Map<String, dynamic>;
        return ListingModel.fromJson(listingJson);
      }).toList();

      return favorites;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<bool> toggleFavorite(String userId, String listingId) async {
    try {
      // Check if already exists
      final checkResponse = await supabaseClient
          .from('wishlists')
          .select()
          .eq('user_id', userId)
          .eq('listing_id', listingId)
          .maybeSingle();

      if (checkResponse != null) {
        // Delete
        await supabaseClient
            .from('wishlists')
            .delete()
            .eq('user_id', userId)
            .eq('listing_id', listingId);
        return false;
      } else {
        // Insert
        await supabaseClient.from('wishlists').insert({
          'user_id': userId,
          'listing_id': listingId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<bool> isFavorite(String userId, String listingId) async {
    try {
      final response = await supabaseClient
          .from('wishlists')
          .select()
          .eq('user_id', userId)
          .eq('listing_id', listingId)
          .maybeSingle();

      return response != null;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
