import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_friend.dart';

/// 老人好友列表（本机演示，按老人 scope 隔离）。
abstract final class CommunityFriendRepository {
  static const String _prefsKeyPrefix = 'interest_comm_friends_v1_';

  static String _bucket(String ownerScopeKey) => '$_prefsKeyPrefix$ownerScopeKey';

  static Future<List<ElderFriend>> loadFriends(String ownerScopeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bucket(ownerScopeKey));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <ElderFriend>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        result.add(ElderFriend.fromJson(item));
      }
      result.sort((a, b) => b.addedAtMillis.compareTo(a.addedAtMillis));
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> loadFriendScopeKeys(String ownerScopeKey) async {
    final friends = await loadFriends(ownerScopeKey);
    return friends.map((f) => f.scopeKey).toSet();
  }

  static Future<bool> isFriend(String ownerScopeKey, String friendScopeKey) async {
    final keys = await loadFriendScopeKeys(ownerScopeKey);
    return keys.contains(friendScopeKey);
  }

  static Future<bool> isFriendByPhone(String ownerScopeKey, String phone) async {
    final friends = await loadFriends(ownerScopeKey);
    final normalized = phone.trim();
    return friends.any((f) => f.phone == normalized);
  }

  static Future<void> addFriend({
    required String ownerScopeKey,
    required ElderFriendCandidate candidate,
  }) async {
    final list = await loadFriends(ownerScopeKey);
    if (list.any((f) => f.scopeKey == candidate.scopeKey || f.phone == candidate.phone)) {
      return;
    }
    list.insert(
      0,
      ElderFriend(
        scopeKey: candidate.scopeKey,
        displayName: candidate.displayName,
        phone: candidate.phone,
        hint: candidate.hint,
        emoji: candidate.emoji,
        addedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bucket(ownerScopeKey),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeFriend({
    required String ownerScopeKey,
    required String friendScopeKey,
  }) async {
    final list = await loadFriends(ownerScopeKey);
    list.removeWhere((f) => f.scopeKey == friendScopeKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bucket(ownerScopeKey),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }
}
