import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_message.dart';

/// 老人与好友的一对一语音消息（本机演示）。
abstract final class CommunityDirectRepository {
  static String _threadKey(String ownerScope, String peerScope) {
    final a = ownerScope.compareTo(peerScope) <= 0 ? ownerScope : peerScope;
    final b = ownerScope.compareTo(peerScope) <= 0 ? peerScope : ownerScope;
    return 'interest_comm_direct_v1_${a}__${b}';
  }

  static Future<List<InterestCommunityVoiceMessage>> loadThread({
    required String ownerScope,
    required String peerScope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_threadKey(ownerScope, peerScope));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <InterestCommunityVoiceMessage>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        result.add(InterestCommunityVoiceMessage.fromJson(item));
      }
      result.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<void> appendMessage({
    required String ownerScope,
    required String peerScope,
    required InterestCommunityVoiceMessage message,
  }) async {
    final list = await loadThread(ownerScope: ownerScope, peerScope: peerScope);
    list.add(message);
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _threadKey(ownerScope, peerScope),
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }
}
