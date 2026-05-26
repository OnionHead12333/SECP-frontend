import 'elder_avatar_repository.dart';
import 'friend_discover_catalog.dart';

/// 解析群成员头像：本机图片或演示 emoji。
abstract final class CommunityAvatarResolver {
  static Future<String?> imagePathForScope(String scopeKey) {
    if (scopeKey.isEmpty || scopeKey == 'system') return Future.value(null);
    return ElderAvatarRepository.loadPath(scopeKey);
  }

  static String? emojiForScope(String scopeKey) {
    return FriendDiscoverCatalog.byScopeKey(scopeKey)?.emoji;
  }

  static Future<Map<String, String>> loadPathsForScopes(
    Iterable<String> scopes, {
    Map<String, String>? remoteAvatarUrlsByScope,
  }) async {
    final map = <String, String>{};
    for (final s in scopes.toSet()) {
      if (s.isEmpty || s == 'system') continue;
      final remote = remoteAvatarUrlsByScope?[s];
      String? path;
      if (remote != null && remote.isNotEmpty) {
        path = await ElderAvatarRepository.ensureCachedFromUrl(
          scopeKey: s,
          avatarUrl: remote,
        );
      }
      path ??= await ElderAvatarRepository.loadPath(s);
      if (path != null) map[s] = path;
    }
    return map;
  }
}
