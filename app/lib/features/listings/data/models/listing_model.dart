import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';

/// Data Transfer Object for Listing.
///
/// This model represents the listing data structure received from Supabase.
/// It includes methods for serialization and mapping to domain entities.
class ListingModel extends Listing {
  const ListingModel({
    required super.id,
    required super.title,
    required super.author,
    required super.priceFcfa,
    required super.condition,
    required super.imageUrl,
    required super.description,
    required super.sellerId,
    required super.status,
    super.category,
    required super.createdAt,
    super.sellerType = 'individual',
    super.isBuyBackEligible = false,
    super.stockCount = 1,
    super.isBoosted = false,
    super.boostExpiresAt,
    super.expiresAt,
    super.sellerName,
    super.sellerLocality,
    super.sellerWhatsapp,
    super.sellerAvatarUrl,
    super.sellerRating,
    super.sellerReviewCount,
    super.latitude,
    super.longitude,
  });

  /// Creates a [ListingModel] from a [cached_listings] SQLite row.
  ///
  /// Only the columns that exist in the local schema are mapped.
  /// Seller-join fields are absent from the cache and default to null,
  /// which is acceptable — cards degrade gracefully when shown offline.
  factory ListingModel.fromCacheRow(Map<String, dynamic> row) {
    return ListingModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      author: row['author'] as String? ?? '',
      priceFcfa: row['price_fcfa'] as int? ?? 0,
      condition: BookCondition.fromValue(row['condition'] as String? ?? 'good'),
      imageUrl: row['image_url'] as String? ?? '',
      description: row['description'] as String? ?? '',
      sellerId: row['seller_id'] as String? ?? '',
      status: row['status'] as String? ?? 'available',
      category: row['category'] as String?,
      createdAt: DateTime.now(), // not stored in cache schema
    );
  }

  /// Creates a ListingModel instance from JSON.
  ///
  /// This factory constructor is typically used when deserializing data
  /// received from Supabase.
  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      priceFcfa: json['price_fcfa'] as int? ?? 0,
      condition: BookCondition.fromValue(
        json['condition'] as String? ?? 'good',
      ),
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      category: json['category'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      sellerType: json['seller_type'] as String? ?? 'individual',
      isBuyBackEligible: json['is_buy_back_eligible'] as bool? ?? false,
      stockCount: json['stock_count'] as int? ?? 1,
      isBoosted: json['is_boosted'] as bool? ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.parse(json['boost_expires_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      sellerName:
          (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      sellerLocality:
          (json['profiles'] as Map<String, dynamic>?)?['locality'] as String?,
      sellerWhatsapp:
          (json['profiles'] as Map<String, dynamic>?)?['whatsapp_number']
              as String?,
      sellerAvatarUrl:
          (json['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
      sellerRating:
          (json['profiles'] as Map<String, dynamic>?)?['rating'] is num
          ? ((json['profiles'] as Map<String, dynamic>?)?['rating'] as num)
                .toDouble()
          : null,
      sellerReviewCount:
          (json['profiles'] as Map<String, dynamic>?)?['review_count'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Converts the ListingModel to JSON.
  ///
  /// This method is used when sending data to Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'price_fcfa': priceFcfa,
      'condition': condition.value,
      'image_url': imageUrl,
      'description': description,
      'seller_id': sellerId,
      'status': status,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'seller_type': sellerType,
      'is_buy_back_eligible': isBuyBackEligible,
      'stock_count': stockCount,
      'is_boosted': isBoosted,
      'boost_expires_at': boostExpiresAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Creates a ListingModel from a domain Listing entity.
  factory ListingModel.fromEntity(Listing listing) {
    return ListingModel(
      id: listing.id,
      title: listing.title,
      author: listing.author,
      priceFcfa: listing.priceFcfa,
      condition: listing.condition,
      imageUrl: listing.imageUrl,
      description: listing.description,
      sellerId: listing.sellerId,
      status: listing.status,
      category: listing.category,
      createdAt: listing.createdAt,
      sellerType: listing.sellerType,
      isBuyBackEligible: listing.isBuyBackEligible,
      stockCount: listing.stockCount,
      isBoosted: listing.isBoosted,
      boostExpiresAt: listing.boostExpiresAt,
      expiresAt: listing.expiresAt,
      sellerName: listing.sellerName,
      sellerLocality: listing.sellerLocality,
      sellerWhatsapp: listing.sellerWhatsapp,
      sellerAvatarUrl: listing.sellerAvatarUrl,
      sellerRating: listing.sellerRating,
      sellerReviewCount: listing.sellerReviewCount,
      latitude: listing.latitude,
      longitude: listing.longitude,
    );
  }

  /// Converts this model to a domain Listing entity.
  Listing toEntity() {
    return Listing(
      id: id,
      title: title,
      author: author,
      priceFcfa: priceFcfa,
      condition: condition,
      imageUrl: imageUrl,
      description: description,
      sellerId: sellerId,
      status: status,
      createdAt: createdAt,
      sellerType: sellerType,
      isBuyBackEligible: isBuyBackEligible,
      stockCount: stockCount,
      isBoosted: isBoosted,
      boostExpiresAt: boostExpiresAt,
      expiresAt: expiresAt,
      sellerName: sellerName,
      sellerLocality: sellerLocality,
      sellerWhatsapp: sellerWhatsapp,
      sellerAvatarUrl: sellerAvatarUrl,
      sellerRating: sellerRating,
      sellerReviewCount: sellerReviewCount,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
