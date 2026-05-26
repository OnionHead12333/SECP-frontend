import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../elder/data/elder_user_profile_api.dart';
import 'community_scope.dart';
import 'interest_community_api.dart';

/// 老人头像：上传走 `POST /v1/elder/profile/avatar`，本机缓存路径供 UI 展示。
abstract final class ElderAvatarRepository {
  static const String _prefsPathPrefix = 'elder_avatar_path_v1_';
  static const String _prefsUrlPrefix = 'elder_avatar_url_v1_';

  static String _pathBucket(String scopeKey) => '$_prefsPathPrefix$scopeKey';
  static String _urlBucket(String scopeKey) => '$_prefsUrlPrefix$scopeKey';

  static Future<String?> loadPath(String scopeKey) async {
    if (scopeKey.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathBucket(scopeKey));
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    if (path != null) await prefs.remove(_pathBucket(scopeKey));

    final url = prefs.getString(_urlBucket(scopeKey));
    if (url != null && url.isNotEmpty) {
      return ensureCachedFromUrl(scopeKey: scopeKey, avatarUrl: url);
    }

    if (scopeKey == CommunityScope.forCurrentElder()) {
      return _syncFromProfile(scopeKey);
    }
    return null;
  }

  /// 上传并写入本机缓存；返回本地文件路径。
  static Future<String> saveFromFile({
    required String scopeKey,
    required String sourcePath,
  }) async {
    final avatarUrl = await ElderUserProfileApi.uploadAvatar(File(sourcePath));
    final target = await _copyToCache(scopeKey, sourcePath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathBucket(scopeKey), target);
    await prefs.setString(_urlBucket(scopeKey), avatarUrl);
    return target;
  }

  /// 按消息里的 `senderAvatarUrl` 拉取并缓存（他人头像）。
  static Future<String?> ensureCachedFromUrl({
    required String scopeKey,
    required String avatarUrl,
  }) async {
    if (scopeKey.isEmpty || avatarUrl.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = prefs.getString(_urlBucket(scopeKey));
    final path = prefs.getString(_pathBucket(scopeKey));
    if (cachedUrl == avatarUrl &&
        path != null &&
        path.isNotEmpty &&
        File(path).existsSync()) {
      return path;
    }
    try {
      final bytes = await _downloadBytes(avatarUrl);
      final local = await _writeBytes(scopeKey, bytes);
      await prefs.setString(_pathBucket(scopeKey), local);
      await prefs.setString(_urlBucket(scopeKey), avatarUrl);
      return local;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String scopeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathBucket(scopeKey));
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    await prefs.remove(_pathBucket(scopeKey));
    await prefs.remove(_urlBucket(scopeKey));
  }

  static Future<String?> _syncFromProfile(String scopeKey) async {
    try {
      final profile = await ElderUserProfileApi.fetchProfile();
      final url = profile.avatarUrl;
      if (url == null || url.isEmpty) return null;
      return ensureCachedFromUrl(scopeKey: scopeKey, avatarUrl: url);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _downloadBytes(String avatarUrl) async {
    final fullUrl = InterestCommunityApi.resolveMediaUrl(avatarUrl);
    final res = await ApiClient.dio.get<List<int>>(
      fullUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data == null) throw Exception('无法加载头像');
    return Uint8List.fromList(data);
  }

  static Future<String> _copyToCache(String scopeKey, String sourcePath) async {
    await File(sourcePath).copy(await _targetPath(scopeKey));
    return _targetPath(scopeKey);
  }

  static Future<String> _writeBytes(String scopeKey, Uint8List bytes) async {
    final target = await _targetPath(scopeKey);
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  static Future<String> _targetPath(String scopeKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/elder_avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    final safeKey = scopeKey.replaceAll(RegExp(r'[^\w.-]'), '_');
    return '${avatarDir.path}/$safeKey.jpg';
  }
}
