import 'package:book_bridge/features/auth/domain/entities/user.dart';

/// Data Transfer Object for User.
///
/// This model represents the user data structure received from Supabase.
/// It includes methods for serialization and mapping to domain entities.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.locality,
    super.whatsappNumber,
    super.avatarUrl,
    super.rating,
    super.reviewCount,
    super.completedDealsCount = 0,
    super.trustScore = 50,
    super.trustLevel = 'Seedling',
    super.fcmToken,
    required super.createdAt,
  });

  /// Creates a UserModel instance from JSON.
  ///
  /// This factory constructor is typically used when deserializing data
  /// received from Supabase (either Auth or Database).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      locality: json['locality'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : null,
      reviewCount: json['review_count'] as int?,
      completedDealsCount: json['completed_deals_count'] as int? ?? 0,
      trustScore: json['trust_score'] as int? ?? 50,
      trustLevel: json['trust_level'] as String? ?? 'Seedling',
      fcmToken: json['fcm_token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the UserModel to JSON.
  ///
  /// This method is used when sending data to Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'locality': locality,
      'whatsapp_number': whatsappNumber,
      'avatar_url': avatarUrl,
      'rating': rating,
      'review_count': reviewCount,
      'completed_deals_count': completedDealsCount,
      'trust_score': trustScore,
      'trust_level': trustLevel,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a UserModel from a domain User entity.
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      locality: user.locality,
      whatsappNumber: user.whatsappNumber,
      avatarUrl: user.avatarUrl,
      rating: user.rating,
      reviewCount: user.reviewCount,
      completedDealsCount: user.completedDealsCount,
      trustScore: user.trustScore,
      trustLevel: user.trustLevel,
      fcmToken: user.fcmToken,
      createdAt: user.createdAt,
    );
  }

  /// Converts this model to a domain User entity.
  User toEntity() {
    return User(
      id: id,
      email: email,
      fullName: fullName,
      locality: locality,
      whatsappNumber: whatsappNumber,
      avatarUrl: avatarUrl,
      rating: rating,
      reviewCount: reviewCount,
      completedDealsCount: completedDealsCount,
      trustScore: trustScore,
      trustLevel: trustLevel,
      fcmToken: fcmToken,
      createdAt: createdAt,
    );
  }
}
