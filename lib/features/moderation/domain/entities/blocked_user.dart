import 'package:equatable/equatable.dart';

/// Someone the signed-in user has blocked.
class BlockedUser extends Equatable {
  final String id;
  final String? name;
  final String? avatarUrl;

  const BlockedUser({required this.id, this.name, this.avatarUrl});

  @override
  List<Object?> get props => [id, name, avatarUrl];
}
