import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/community_message.dart';
import '../models/community_message_page.dart';
import 'community_api_util.dart';
import 'community_message_upload.dart';

/// 老人端一对一私聊 — 对接 docs/兴趣社群-老人端私聊-OpenAPI.md
final class InterestCommunityDirectApi {
  InterestCommunityDirectApi._();

  static const String _prefix = '/v1/elder/direct-messages';

  static String _messagesPath(String peerScopeKey) =>
      '$_prefix/threads/${Uri.encodeComponent(peerScopeKey)}/messages';

  static void _throwIfFail(ApiResponse<dynamic> api) => CommunityApiUtil.throwIfFail(api);

  static Map<String, dynamic> _asMap(Object? raw) => CommunityApiUtil.asMap(raw);

  static Future<CommunityMessagePage> listDirectMessagesPage(
    String peerScopeKey, {
    String? before,
    int limit = 50,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      _messagesPath(peerScopeKey),
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': limit,
      },
    );
    return _parseMessagePageResult(res.data);
  }

  /// 拉取当前线程全部可见历史（自动翻页，最多 [maxPages] 页）。
  static Future<List<InterestCommunityVoiceMessage>> listDirectMessages(
    String peerScopeKey, {
    int limit = 50,
    int maxPages = 20,
  }) async {
    final merged = <InterestCommunityVoiceMessage>[];
    final seen = <String>{};
    String? before;
    var hasMore = true;
    var pages = 0;
    while (hasMore && pages < maxPages) {
      final page = await listDirectMessagesPage(peerScopeKey, before: before, limit: limit);
      if (before == null) {
        for (final m in page.items) {
          if (seen.add(m.id)) merged.add(m);
        }
      } else {
        final older = <InterestCommunityVoiceMessage>[];
        for (final m in page.items) {
          if (seen.add(m.id)) older.add(m);
        }
        merged.insertAll(0, older);
      }
      hasMore = page.hasMore;
      before = page.nextBefore;
      pages++;
      if (page.items.isEmpty) break;
    }
    merged.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return merged;
  }

  static Future<InterestCommunityVoiceMessage> sendDirectText(
    String peerScopeKey, {
    required String textContent,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      _messagesPath(peerScopeKey),
      data: CommunityApiUtil.textMessageBody(textContent),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    return _parseSingleMessage(res.data);
  }

  static Future<InterestCommunityVoiceMessage> sendDirectVoice(
    String peerScopeKey, {
    required File file,
    int? durationMs,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      _messagesPath(peerScopeKey),
      data: await CommunityMessageUpload.voiceFormData(file, durationMs: durationMs),
      options: CommunityMessageUpload.uploadOptions,
    );
    return _parseSingleMessage(res.data);
  }

  static Future<InterestCommunityVoiceMessage> sendDirectImage(
    String peerScopeKey, {
    required File file,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      _messagesPath(peerScopeKey),
      data: await CommunityMessageUpload.imageFormData(file),
      options: CommunityMessageUpload.uploadOptions,
    );
    return _parseSingleMessage(res.data);
  }

  static Future<void> clearDirectChatHistory(String peerScopeKey) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      _messagesPath(peerScopeKey),
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = CommunityApiUtil.parseEnvelope(body);
    CommunityApiUtil.throwIfFail(api);
  }

  static CommunityMessagePage _parseMessagePageResult(Map<String, dynamic>? body) {
    if (body == null) throw Exception('空响应');
    final api = CommunityApiUtil.parseEnvelope(body);
    _throwIfFail(api);
    final data = api.data ?? _asMap(body['data']);
    if (data.isEmpty) {
      return const CommunityMessagePage(items: [], hasMore: false);
    }
    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .map((e) => _parseDirectMessage(_asMap(e)))
            .toList()
        : <InterestCommunityVoiceMessage>[];
    final hasMore = data['hasMore'] == true || data['has_more'] == true;
    final nextBefore = data['nextBefore'] as String? ?? data['next_before'] as String?;
    return CommunityMessagePage(
      items: items,
      hasMore: hasMore,
      nextBefore: nextBefore,
    );
  }

  static InterestCommunityVoiceMessage _parseSingleMessage(Map<String, dynamic>? body) {
    final data = CommunityApiUtil.requireMessageData(body);
    return _parseDirectMessage(data);
  }

  /// 确保 `communityId` 为 `direct`，便于与群聊共用 UI/缓存逻辑。
  static InterestCommunityVoiceMessage _parseDirectMessage(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final cid = normalized['communityId'] ?? normalized['community_id'];
    if (cid == null || '$cid'.isEmpty) {
      normalized['communityId'] = 'direct';
    }
    return InterestCommunityVoiceMessage.fromJson(normalized);
  }
}
