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
    super.schoolId,
    super.tier = 'free',
    super.ageDeclaration,
    super.ageDeclaredAt,
    super.idVerificationStatus = 'unverified',
    super.idType,
    super.dateOfBirth,
    super.guardianPhone,
    super.idRejectionReason,
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
      schoolId: json['school_id'] as String?,
      tier: json['tier'] as String? ?? 'free',
      ageDeclaration: json['age_declaration'] as String?,
      ageDeclaredAt: json['age_declared_at'] != null
          ? DateTime.parse(json['age_declared_at'] as String)
          : null,
      idVerificationStatus:
          json['id_verification_status'] as String? ?? 'unverified',
      idType: json['id_type'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      guardianPhone: json['guardian_phone'] as String?,
      idRejectionReason: json['id_rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Columns of the `public_profiles` view, the only profile data readable
  /// for other users (`profiles` itself is owner-only under RLS).
  static const String publicProfileColumns =
      'id, full_name, locality, avatar_url, rating, review_count, '
      'trust_score, trust_level, completed_deals_count, created_at, tier, '
      'id_verified';

  /// Creates a UserModel for another user from a `public_profiles` row.
  ///
  /// Contact, age and ID details are never exposed for other users, so
  /// email is empty and only the verified/unverified status is known.
  factory UserModel.fromPublicProfile(Map<String, dynamic> json) {
    return UserModel.fromJson({
      ...json,
      'email': '',
      'id_verification_status': json['id_verified'] == true
          ? 'verified'
          : 'unverified',
    });
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
      'school_id': schoolId,
      'tier': tier,
      'age_declaration': ageDeclaration,
      'age_declared_at': ageDeclaredAt?.toIso8601String(),
      'id_verification_status': idVerificationStatus,
      'id_type': idType,
      'date_of_birth': dateOfBirth?.toIso8601String().substring(0, 10),
      'guardian_phone': guardianPhone,
      'id_rejection_reason': idRejectionReason,
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
      schoolId: user.schoolId,
      tier: user.tier,
      ageDeclaration: user.ageDeclaration,
      ageDeclaredAt: user.ageDeclaredAt,
      idVerificationStatus: user.idVerificationStatus,
      idType: user.idType,
      dateOfBirth: user.dateOfBirth,
      guardianPhone: user.guardianPhone,
      idRejectionReason: user.idRejectionReason,
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
      schoolId: schoolId,
      tier: tier,
      ageDeclaration: ageDeclaration,
      ageDeclaredAt: ageDeclaredAt,
      idVerificationStatus: idVerificationStatus,
      idType: idType,
      dateOfBirth: dateOfBirth,
      guardianPhone: guardianPhone,
      idRejectionReason: idRejectionReason,
      createdAt: createdAt,
    );
  }
}
