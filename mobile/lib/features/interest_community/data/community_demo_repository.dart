import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_message.dart';

/// 前端演示：不写后端接口，仅用本机存储模拟「群内语音消息」会话。
abstract final class CommunityDemoRepository {
  static const String _prefsKeyPrefix = 'interest_comm_voice_msgs_v1_';
  static const String _peerSeedFlagPrefix = 'interest_comm_peer_seeded_v1_';

  static String _bucket(String communityId) => '$_prefsKeyPrefix$communityId';

  static String _peerSeedFlag(String communityId) => '$_peerSeedFlagPrefix$communityId';

  static Future<List<InterestCommunityVoiceMessage>> loadMessages(
    String communityId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bucket(communityId));
    if (raw == null || raw.isEmpty) return [];
    List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      list = decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
    final result = <InterestCommunityVoiceMessage>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(InterestCommunityVoiceMessage.fromJson(item));
      } catch (_) {}
    }
    result.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return result;
  }

  static Future<void> _saveAll(String communityId, List<InterestCommunityVoiceMessage> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bucket(communityId),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> appendMessage(InterestCommunityVoiceMessage message) async {
    final list = await loadMessages(message.communityId);
    list.add(message);
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    await _saveAll(message.communityId, trimmed);
  }

  static Future<InterestCommunityVoiceMessage?> latestMessage(String communityId) async {
    final list = await loadMessages(communityId);
    if (list.isEmpty) return null;
    return list.last;
  }

  static Future<void> ensureWelcomeSeed({
    required String communityId,
    required String communityName,
  }) async {
    final list = await loadMessages(communityId);
    if (list.isNotEmpty) return;
    await appendMessage(
      InterestCommunityVoiceMessage(
        id: 'welcome_$communityId',
        communityId: communityId,
        role: CommunitySenderRole.elder,
        senderDisplay: '群助手',
        senderScopeKey: 'system',
        kind: CommunityMessageKind.text,
        textContent: '欢迎来到$communityName！按住底部绿色按钮即可发送语音消息。',
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 演示：补充群友「昨天」的左侧消息，与老人端/子女端共用同一份记录。
  static Future<void> seedPeerMessagesIfNeeded(String communityId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_peerSeedFlag(communityId)) == true) return;

    final now = DateTime.now();
    final yesterdayMorning = DateTime(now.year, now.month, now.day - 1, 9, 20);
    final yesterdayNoon = DateTime(now.year, now.month, now.day - 1, 14, 35);

    final peers = [
      InterestCommunityVoiceMessage(
        id: 'demo_peer_${communityId}_1',
        communityId: communityId,
        role: CommunitySenderRole.elder,
        senderDisplay: '王阿姨',
        senderScopeKey: 'demo_peer_wang',
        kind: CommunityMessageKind.text,
        textContent: '大家明天照常去公园练太极，记得带水杯。',
        createdAtMillis: yesterdayMorning.millisecondsSinceEpoch,
      ),
      InterestCommunityVoiceMessage(
        id: 'demo_peer_${communityId}_2',
        communityId: communityId,
        role: CommunitySenderRole.elder,
        senderDisplay: '李叔叔',
        senderScopeKey: 'demo_peer_li',
        kind: CommunityMessageKind.text,
        textContent: '收到，我上午也过去，咱们老地方见。',
        createdAtMillis: yesterdayNoon.millisecondsSinceEpoch,
      ),
    ];

    final list = await loadMessages(communityId);
    list.addAll(peers);
    list.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    await _saveAll(communityId, list);
    await prefs.setBool(_peerSeedFlag(communityId), true);
  }

  /// 清空本群全部聊天记录（老人端与子女端同步生效）。
  static Future<void> clearMessages(String communityId) async {
    final list = await loadMessages(communityId);
    for (final msg in list) {
      final path = msg.audioPath;
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bucket(communityId));
  }
}
