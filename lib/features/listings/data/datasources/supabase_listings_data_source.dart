import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/data/models/listing_model.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/subscriptions/domain/subscription_constants.dart';

/// Data source for listing operations using Supabase PostgreSQL and Storage.
///
/// This class handles all listing-related queries to the Supabase database and storage.
class SupabaseListingsDataSource {
  static const String _listingSelect =
      '*, profiles:public_profiles!seller_id(id, full_name, locality, avatar_url, rating, review_count), '
      'class_level:class_levels!class_level_id(id, label), '
      'subject:subjects!subject_id(id, name), '
      'school:schools!school_id(id, name)';

  static const int _filteredSearchWindow = 500;

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
    AcademicFilters filters = AcademicFilters.none,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = supabaseClient
          .from('listings')
          .select(_listingSelect)
          .eq('status', status);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (filters.classLevelId != null) {
        query = query.eq('class_level_id', filters.classLevelId!);
      }
      if (filters.subjectId != null) {
        query = query.eq('subject_id', filters.subjectId!);
      }
      if (filters.schoolId != null) {
        query = query.eq('school_id', filters.schoolId!);
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
          .select(_listingSelect)
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
          .select(_listingSelect)
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
    AcademicFilters filters = AcademicFilters.none,
    int limit = 50,
  }) async {
    try {
      // search_listings applies _limit internally, before PostgREST filters
      // run. Widen the RPC window when filtering so matches aren't cut off,
      // then apply the caller's limit after filtering.
      var request = supabaseClient.rpc(
        'search_listings',
        params: {
          'query': query,
          '_limit': filters.isEmpty ? limit : _filteredSearchWindow,
          '_offset': 0,
        },
      );
      if (filters.classLevelId != null) {
        request = request.eq('class_level_id', filters.classLevelId!);
      }
      if (filters.subjectId != null) {
        request = request.eq('subject_id', filters.subjectId!);
      }
      if (filters.schoolId != null) {
        request = request.eq('school_id', filters.schoolId!);
      }

      final response = await request
          .select(_listingSelect)
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
    List<String> imageUrls = const [],
    String? description,
    String? category,
    String sellerType = 'individual',
    bool isBuyBackEligible = false,
    int stockCount = 1,
    double? latitude,
    double? longitude,
    String? classLevelId,
    String? subjectId,
    String? schoolId,
    String? meetupSpot,
    double? meetupLatitude,
    double? meetupLongitude,
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
            'image_url': imageUrls.isEmpty ? imageUrl : imageUrls.first,
            'image_urls': imageUrls.isEmpty ? [imageUrl] : imageUrls,
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
            'class_level_id': classLevelId,
            'subject_id': subjectId,
            'school_id': schoolId,
            'meetup_spot': meetupSpot,
            'meetup_latitude': meetupLatitude,
            'meetup_longitude': meetupLongitude,
          })
          .select(_listingSelect)
          .single();

      return ListingModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001' && isFreeTierLimitError(e.message)) {
        throw ServerException(message: kFreeTierLimitError);
      }
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
    List<String>? imageUrls,
    String? description,
    String? category,
    String? sellerType,
    bool? isBuyBackEligible,
    int? stockCount,
    double? latitude,
    double? longitude,
    String? classLevelId,
    String? subjectId,
    String? schoolId,
    bool clearSchool = false,
    String? meetupSpot,
    double? meetupLatitude,
    double? meetupLongitude,
    bool updateMeetup = false,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (author != null) updates['author'] = author;
      if (priceFcfa != null) updates['price_fcfa'] = priceFcfa;
      if (condition != null) updates['condition'] = condition.value;
      if (imageUrls != null && imageUrls.isNotEmpty) {
        updates['image_urls'] = imageUrls;
        updates['image_url'] = imageUrls.first;
      } else if (imageUrl != null) {
        updates['image_url'] = imageUrl;
      }
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (sellerType != null) updates['seller_type'] = sellerType;
      if (isBuyBackEligible != null) {
        updates['is_buy_back_eligible'] = isBuyBackEligible;
      }
      if (stockCount != null) updates['stock_count'] = stockCount;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (classLevelId != null) updates['class_level_id'] = classLevelId;
      if (subjectId != null) updates['subject_id'] = subjectId;
      if (schoolId != null) {
        updates['school_id'] = schoolId;
      } else if (clearSchool) {
        updates['school_id'] = null;
      }
      if (updateMeetup) {
        updates['meetup_spot'] = meetupSpot;
        updates['meetup_latitude'] = meetupLatitude;
        updates['meetup_longitude'] = meetupLongitude;
      }

      final response = await supabaseClient
          .from('listings')
          .update(updates)
          .eq('id', id)
          .select(_listingSelect)
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

  /// Fetches all class levels ordered for display.
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<ClassLevel>> getClassLevels() async {
    try {
      final response = await supabaseClient
          .from('class_levels')
          .select('id, system, code, label')
          .order('sort_order');
      return (response as List<dynamic>)
          .map((e) => ClassLevel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetches all subjects ordered for display.
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<Subject>> getSubjects() async {
    try {
      final response = await supabaseClient
          .from('subjects')
          .select('id, code, name')
          .order('sort_order');
      return (response as List<dynamic>)
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Searches schools by name (case-insensitive substring match).
  ///
  /// Throws [ServerException] if the query fails.
  Future<List<School>> searchSchools(String query, {int limit = 20}) async {
    try {
      var request = supabaseClient
          .from('schools')
          .select('id, name, town, region');
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        // Escape LIKE wildcards so user input is matched literally.
        final escaped = trimmed
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        request = request.ilike('name', '%$escaped%');
      }
      final response = await request.order('name').limit(limit);
      return (response as List<dynamic>)
          .map((e) => School.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetches a single school by ID, or null if it does not exist.
  ///
  /// Throws [ServerException] if the query fails.
  Future<School?> getSchoolById(String id) async {
    try {
      final response = await supabaseClient
          .from('schools')
          .select('id, name, town, region')
          .eq('id', id)
          .maybeSingle();
      return response == null ? null : School.fromJson(response);
    } on PostgrestException catch (e) {
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
