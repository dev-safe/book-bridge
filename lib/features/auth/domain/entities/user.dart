import 'package:equatable/equatable.dart';

/// Represents a user in the BookBridge application.
///
/// This is a domain entity that contains the core user information
/// and is independent of any data source or framework.
class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? locality;
  final String? whatsappNumber;
  final String? avatarUrl;
  final double? rating;
  final int? reviewCount;
  final int completedDealsCount;
  final int trustScore;
  final String trustLevel;
  final String? fcmToken;

  /// Self-declared school (references `schools.id`), used as the default
  /// school on new listings.
  final String? schoolId;

  /// Seller tier: `free` or `power_seller`. Set by the server only.
  final String tier;

  /// Self-declared age status: `adult` (18+) or `guardian` (a parent or
  /// guardian completes purchases). Null until the user declares. This is a
  /// declaration, not a verification. Set via the `declare_age` RPC only.
  final String? ageDeclaration;
  final DateTime? ageDeclaredAt;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.locality,
    this.whatsappNumber,
    this.avatarUrl,
    this.rating,
    this.reviewCount,
    this.completedDealsCount = 0,
    this.trustScore = 50,
    this.trustLevel = 'Seedling',
    this.fcmToken,
    this.schoolId,
    this.tier = 'free',
    this.ageDeclaration,
    this.ageDeclaredAt,
    required this.createdAt,
  });

  bool get isPowerSeller => tier == 'power_seller';

  bool get hasAgeDeclaration => ageDeclaration != null;

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? locality,
    String? whatsappNumber,
    String? avatarUrl,
    double? rating,
    int? reviewCount,
    int? completedDealsCount,
    int? trustScore,
    String? trustLevel,
    String? fcmToken,
    String? schoolId,
    bool clearSchool = false,
    String? tier,
    String? ageDeclaration,
    DateTime? ageDeclaredAt,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      locality: locality ?? this.locality,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      completedDealsCount: completedDealsCount ?? this.completedDealsCount,
      trustScore: trustScore ?? this.trustScore,
      trustLevel: trustLevel ?? this.trustLevel,
      fcmToken: fcmToken ?? this.fcmToken,
      schoolId: clearSchool ? null : (schoolId ?? this.schoolId),
      tier: tier ?? this.tier,
      ageDeclaration: ageDeclaration ?? this.ageDeclaration,
      ageDeclaredAt: ageDeclaredAt ?? this.ageDeclaredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    locality,
    whatsappNumber,
    avatarUrl,
    rating,
    reviewCount,
    completedDealsCount,
    trustScore,
    trustLevel,
    fcmToken,
    schoolId,
    tier,
    ageDeclaration,
    ageDeclaredAt,
    createdAt,
  ];
}
