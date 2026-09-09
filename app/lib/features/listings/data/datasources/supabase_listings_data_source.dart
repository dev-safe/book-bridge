import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/data/models/listing_model.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';

/// Data source for listing operations using Supabase PostgreSQL and Storage.
///
/// This class handles all listing-related queries to the Supabase database and storage.
class SupabaseListingsDataSource {
  final SupabaseClient supabaseClient;
  final SupabaseStorageDataSource storageDataSource;

  SupabaseListingsDataSource({
    required this.supabaseClient,
    required this.storageDataSource,
  });

  /// Fetches all academic categories.
  Future<List<Map<String, dynamic>>> getCategories() async {
    // For now, we return a hardcoded list of real Cameroonian categories.
    // In a future update, this could fetch from a 'categories' table in Supabase.
    return [
      {
        'id': 'eng',
        'name': 'Engineering',
        'icon': 'engineering',
        'subtitle': 'Polytechnique / HTTC',
      },
      {
        'id': 'law',
        'name': 'Law',
        'icon': 'gavel',
        'subtitle': 'FSJP / Political Science',
      },
      {
        'id': 'med',
        'name': 'Medicine',
        'icon': 'medical_services',
        'subtitle': 'FMSB / Health Sciences',
      },
      {
        'id': 'eco',
        'name': 'Economics',
        'icon': 'payments',
        'subtitle': 'FSEG / Management',
      },
      {
        'id': 'art',
        'name': 'Arts & Letters',
        'icon': 'menu_book',
        'subtitle': 'FALSH / Social Sci.',
      },
      {
        'id': 'sci',
        'name': 'Science',
        'icon': 'science',
        'subtitle': 'FS / Technology',
      },
    ];
  }

  /// Fetches all available listings with pagination.
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<ListingModel>> getListings({
    String status = 'available',
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = supabaseClient
          .from('listings')
          .select('*, profiles:seller_id(*)')
          .eq('status', status);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      final response = await query
          .order('is_boosted', ascending: false)
          .order('boost_expires_at', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final listings = (response as List<dynamic>)
          .map((item) => ListingModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return listings;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetches a single listing by ID.
  ///
  /// Throws [NotFoundException] if listing not found.
  /// Throws [ServerException] if the query fails.
  Future<ListingModel> getListingDetails(String listingId) async {
    try {
      final response = await supabaseClient
          .from('listings')
          .select('*, profiles:seller_id(*)')
          .eq('id', listingId)
          .single();

      return ListingModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException(message: 'Listing not found');
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetches all listings from a specific seller.
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<ListingModel>> getListingsBySeller(String sellerId) async {
    try {
      final response = await supabaseClient
          .from('listings')
          .select('*, profiles:seller_id(*)')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      final listings = (response as List<dynamic>)
          .map((item) => ListingModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return listings;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Searches listings by title or author.
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<ListingModel>> searchListings(
    String query, {
    int limit = 50,
  }) async {
    try {
      final response = await supabaseClient
          .rpc(
            'search_listings',
            params: {
              'query': query,
              '_limit': limit,
              '_offset':
                  0, // Assuming offset will be handled by the RPC if needed
            },
          )
          .select('*, profiles:seller_id(*)')
          .order('is_boosted', ascending: false)
          .order('boost_expires_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      final listings = (response as List<dynamic>)
          .map((item) => ListingModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return listings;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Creates a new listing.
  ///
  /// Throws [ServerException] if the operation fails.
  Future<ListingModel> createListing({
    required String title,
    required String author,
    required int priceFcfa,
    required BookCondition condition,
    required String imageUrl,
    String? description,
    String? category,
    String sellerType = 'individual',
    bool isBuyBackEligible = false,
    int stockCount = 1,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final response = await supabaseClient
          .from('listings')
          .insert({
            'title': title,
            'author': author,
            'price_fcfa': priceFcfa,
            'condition': condition.value,
            'image_url': imageUrl,
            'description': description,
            'category': category,
            'seller_id': userId,
            'status': 'available',
            'created_at': DateTime.now().toIso8601String(),
            'seller_type': sellerType,
            'is_buy_back_eligible': isBuyBackEligible,
            'stock_count': stockCount,
            'latitude': latitude,
            'longitude': longitude,
          })
          .select()
          .single();

      return ListingModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Deletes a listing.
  ///
  /// Throws [NotFoundException] if listing not found.
  /// Throws [ServerException] if the operation fails.
  Future<void> deleteListing(String listingId) async {
    try {
      await supabaseClient.from('listings').delete().eq('id', listingId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException(message: 'Listing not found');
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Updates an existing listing.
  ///
  /// Throws [NotFoundException] if listing not found.
  /// Throws [ServerException] if the operation fails.
  Future<ListingModel> updateListing({
    required String id,
    String? title,
    String? author,
    int? priceFcfa,
    BookCondition? condition,
    String? imageUrl,
    String? description,
    String? category,
    String? sellerType,
    bool? isBuyBackEligible,
    int? stockCount,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (author != null) updates['author'] = author;
      if (priceFcfa != null) updates['price_fcfa'] = priceFcfa;
      if (condition != null) updates['condition'] = condition.value;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (sellerType != null) updates['seller_type'] = sellerType;
      if (isBuyBackEligible != null) {
        updates['is_buy_back_eligible'] = isBuyBackEligible;
      }
      if (stockCount != null) updates['stock_count'] = stockCount;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;

      final response = await supabaseClient
          .from('listings')
          .update(updates)
          .eq('id', id)
          .select('*, profiles:seller_id(*)')
          .single();

      return ListingModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException(message: 'Listing not found');
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Uploads a book image to Supabase Storage.
  ///
  /// Throws [ServerException] if the upload fails.
  Future<String> uploadBookImage(File imageFile) async {
    return await storageDataSource.uploadBookImage(imageFile);
  }

  /// Deletes a book image from Supabase Storage.
  ///
  /// Throws [ServerException] if the deletion fails.
  Future<void> deleteBookImage(String imagePath) async {
    await storageDataSource.deleteBookImage(imagePath);
  }
}
