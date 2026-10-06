/// The ids of users the signed-in user has blocked, shared with the data
/// sources that hide their listings and conversations. Kept up to date by
/// `ModerationViewModel`.
class BlockedUsersCache {
  Set<String> _ids = const {};

  Set<String> get ids => _ids;

  bool get isEmpty => _ids.isEmpty;

  bool contains(String userId) => _ids.contains(userId);

  void replaceAll(Iterable<String> ids) => _ids = Set.unmodifiable(ids);

  void add(String userId) => _ids = Set.unmodifiable({..._ids, userId});

  void remove(String userId) =>
      _ids = Set.unmodifiable(_ids.where((id) => id != userId));

  void clear() => _ids = const {};
}
