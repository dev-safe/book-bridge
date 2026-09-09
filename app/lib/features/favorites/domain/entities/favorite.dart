import 'package:equatable/equatable.dart';

class Favorite extends Equatable {
  final String id;
  final String userId;
  final String listingId;
  final DateTime createdAt;

  const Favorite({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, listingId, createdAt];
}
