import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'community_demo_repository.dart';

/// 前端演示：记录老人加入了哪些兴趣群（按 scope 区分不同老人账号）。
abstract final class CommunityMembershipRepository {
  static const String _prefsKeyPrefix = 'interest_comm_joined_v1_';

  static String _bucket(String scopeKey) => '$_prefsKeyPrefix$scopeKey';

  static Future<Set<String>> loadJoinedIds(String scopeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bucket(scopeKey));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isJoined(String scopeKey, String communityId) async {
    final joined = await loadJoinedIds(scopeKey);
    return joined.contains(communityId);
  }

  static Future<void> join({
    required String scopeKey,
    required String communityId,
    required String communityName,
  }) async {
    final joined = await loadJoinedIds(scopeKey);
    if (joined.contains(communityId)) return;
    joined.add(communityId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bucket(scopeKey), jsonEncode(joined.toList()));
    await CommunityDemoRepository.ensureWelcomeSeed(
      communityId: communityId,
      communityName: communityName,
    );
  }

  static Future<void> leave(String scopeKey, String communityId) async {
    final joined = await loadJoinedIds(scopeKey);
    if (!joined.remove(communityId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bucket(scopeKey), jsonEncode(joined.toList()));
  }
}
