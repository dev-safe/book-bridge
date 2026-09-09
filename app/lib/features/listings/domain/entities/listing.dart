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

  final String imageUrl;
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
  final String? sellerWhatsapp;
  final String? sellerAvatarUrl;
  final double? sellerRating;
  final int? sellerReviewCount;

  // Location
  final double? latitude;
  final double? longitude;

  const Listing({
    required this.id,
    required this.title,
    required this.author,
    required this.priceFcfa,
    required this.condition,
    required this.imageUrl,
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
    this.sellerWhatsapp,
    this.sellerAvatarUrl,
    this.sellerRating,
    this.sellerReviewCount,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    priceFcfa,
    condition,
    imageUrl,
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
    sellerWhatsapp,
    sellerAvatarUrl,
    sellerRating,
    sellerReviewCount,
    latitude,
    longitude,
  ];
}
