import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'community_chat_visibility_repository.dart';
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
    return _loadAllMessages(communityId);
  }

  /// 按查看者 scope 过滤已「清空」的历史（仅自己不可见，群数据仍保留）。
  static Future<List<InterestCommunityVoiceMessage>> loadMessagesForViewer({
    required String communityId,
    required String viewerScopeKey,
  }) async {
    final all = await _loadAllMessages(communityId);
    final clearBefore = await CommunityChatVisibilityRepository.loadClearBeforeMillis(
      viewerScopeKey,
      communityId,
    );
    if (clearBefore == null) return all;
    return all.where((m) => m.createdAtMillis > clearBefore).toList();
  }

  static Future<List<InterestCommunityVoiceMessage>> _loadAllMessages(
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
    final list = await _loadAllMessages(message.communityId);
    list.add(message);
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    await _saveAll(message.communityId, trimmed);
  }

  static Future<InterestCommunityVoiceMessage?> latestMessage(String communityId) async {
    final list = await _loadAllMessages(communityId);
    if (list.isEmpty) return null;
    return list.last;
  }

  static Future<InterestCommunityVoiceMessage?> latestMessageForViewer({
    required String communityId,
    required String viewerScopeKey,
  }) async {
    final list = await loadMessagesForViewer(
      communityId: communityId,
      viewerScopeKey: viewerScopeKey,
    );
    if (list.isEmpty) return null;
    return list.last;
  }

  static Future<void> ensureWelcomeSeed({
    required String communityId,
    required String communityName,
  }) async {
    final list = await _loadAllMessages(communityId);
    if (list.isNotEmpty) return;
    await appendMessage(
      InterestCommunityVoiceMessage(
        id: 'welcome_$communityId',
        communityId: communityId,
        role: CommunitySenderRole.elder,
        senderDisplay: '群助手',
        senderScopeKey: 'system',
        kind: CommunityMessageKind.text,
        textContent: '欢迎来到$communityName！可按住说话、点键盘图标输入文字，或点 + 发送图片。',
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

    final list = await _loadAllMessages(communityId);
    list.addAll(peers);
    list.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    await _saveAll(communityId, list);
    await prefs.setBool(_peerSeedFlag(communityId), true);
  }

  /// 当前用户在本群清空聊天记录：仅对自己隐藏此前消息，不删除群共享数据与媒体文件。
  static Future<void> hideHistoryForViewer({
    required String communityId,
    required String viewerScopeKey,
  }) async {
    await CommunityChatVisibilityRepository.hideHistoryBeforeNow(
      viewerScopeKey,
      communityId,
    );
  }
}
