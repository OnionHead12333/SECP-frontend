import 'elder_avatar_repository.dart';

/// 解析群成员头像：远端 URL 缓存或本地上传缓存路径。
abstract final class CommunityAvatarResolver {
  static Future<String?> imagePathForScope(String scopeKey) {
    if (scopeKey.isEmpty || scopeKey == 'system') return Future.value(null);
    return ElderAvatarRepository.loadPath(scopeKey);
  }

  /// emoji 由消息/好友接口 `senderEmoji` 字段提供，此处不再读本地目录。
  static String? emojiForScope(String scopeKey) => null;

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
