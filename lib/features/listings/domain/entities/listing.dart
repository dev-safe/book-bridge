import 'package:equatable/equatable.dart';
import 'book_condition.dart';

/// Represents a book listing in the BookBridge marketplace.
///
/// This is a domain entity that contains the core listing information
/// and is independent of any data source or framework.
class Listing extends Equatable {
  final String id;
  final String title;
  final String author;
  final int priceFcfa;
  final BookCondition condition;

  /// Maximum number of photos per listing.
  static const int maxImages = 3;

  /// Cover photo; always equals the first entry of [imageUrls] when set.
  final String imageUrl;

  /// All photos, cover first (up to [maxImages]). Empty for legacy rows
  /// and the offline cache; use [gallery] for display.
  final List<String> imageUrls;
  final String sellerId;
  final String description;
  final String status; // 'available', 'sold'
  final String? category; // Category of the book
  final DateTime createdAt;

  // Social Venture Features
  final String sellerType; // 'individual', 'bookshop', 'author'
  final bool isBuyBackEligible;
  final int stockCount; // For bookshops
  final bool isFeatured; // For featured listings
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final DateTime? expiresAt;

  // Seller info (populated from join)
  final String? sellerName;
  final String? sellerLocality;
  final String? sellerAvatarUrl;
  final double? sellerRating;
  final int? sellerReviewCount;

  // Location
  final double? latitude;
  final double? longitude;

  // Academic classification (labels populated from lookup-table joins)
  final String? classLevelId;
  final String? classLevelLabel;
  final String? subjectId;
  final String? subjectName;
  final String? schoolId;
  final String? schoolName;

  // Seller-chosen meetup spot (#33); the pin is optional and pre-rounded.
  final String? meetupSpot;
  final double? meetupLatitude;
  final double? meetupLongitude;

  const Listing({
    required this.id,
    required this.title,
    required this.author,
    required this.priceFcfa,
    required this.condition,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.sellerId,
    required this.status,
    this.category,
    required this.createdAt,
    this.sellerType = 'individual',
    this.isBuyBackEligible = false,
    this.stockCount = 1,
    this.isFeatured = false,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.expiresAt,
    this.sellerName,
    this.sellerLocality,
    this.sellerAvatarUrl,
    this.sellerRating,
    this.sellerReviewCount,
    this.latitude,
    this.longitude,
    this.classLevelId,
    this.classLevelLabel,
    this.subjectId,
    this.subjectName,
    this.schoolId,
    this.schoolName,
    this.meetupSpot,
    this.meetupLatitude,
    this.meetupLongitude,
  });

  /// Whether the seller dropped a map pin for the meetup spot.
  bool get hasMeetupPin => meetupLatitude != null && meetupLongitude != null;

  /// Photos to display, cover first, falling back to the cover alone.
  List<String> get gallery {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    priceFcfa,
    condition,
    imageUrl,
    imageUrls,
    description,
    sellerId,
    status,
    category,
    createdAt,
    sellerType,
    isBuyBackEligible,
    stockCount,
    isFeatured,
    isBoosted,
    boostExpiresAt,
    expiresAt,
    sellerName,
    sellerLocality,
    sellerAvatarUrl,
    sellerRating,
    sellerReviewCount,
    latitude,
    longitude,
    classLevelId,
    classLevelLabel,
    subjectId,
    subjectName,
    schoolId,
    schoolName,
    meetupSpot,
    meetupLatitude,
    meetupLongitude,
  ];
}
