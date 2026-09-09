import 'package:book_bridge/features/favorites/domain/entities/favorite.dart';

class FavoriteModel extends Favorite {
  const FavoriteModel({
    required super.id,
    required super.userId,
    required super.listingId,
    required super.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      listingId: json['listing_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'listing_id': listingId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FavoriteModel.fromEntity(Favorite entity) {
    return FavoriteModel(
      id: entity.id,
      userId: entity.userId,
      listingId: entity.listingId,
      createdAt: entity.createdAt,
    );
  }

  Favorite toEntity() {
    return Favorite(
      id: id,
      userId: userId,
      listingId: listingId,
      createdAt: createdAt,
    );
  }
}
