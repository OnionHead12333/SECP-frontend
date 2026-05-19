import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 老人/群成员头像（本机路径，按 scope 存储）。
abstract final class ElderAvatarRepository {
  static const String _prefsKeyPrefix = 'elder_avatar_path_v1_';

  static String _bucket(String scopeKey) => '$_prefsKeyPrefix$scopeKey';

  static Future<String?> loadPath(String scopeKey) async {
    if (scopeKey.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_bucket(scopeKey));
    if (path == null || path.isEmpty) return null;
    if (!File(path).existsSync()) {
      await prefs.remove(_bucket(scopeKey));
      return null;
    }
    return path;
  }

  static Future<String> saveFromFile({
    required String scopeKey,
    required String sourcePath,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/elder_avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    final safeKey = scopeKey.replaceAll(RegExp(r'[^\w.-]'), '_');
    final target = File('${avatarDir.path}/$safeKey.jpg');
    await File(sourcePath).copy(target.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bucket(scopeKey), target.path);
    return target.path;
  }

  static Future<void> clear(String scopeKey) async {
    final path = await loadPath(scopeKey);
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bucket(scopeKey));
  }
}
