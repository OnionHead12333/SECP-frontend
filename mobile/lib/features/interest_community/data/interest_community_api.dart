import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/community_join_result.dart';
import '../models/community_message.dart';
import '../models/community_message_page.dart';
import 'community_media_downloader.dart';

/// 兴趣社群群聊 / 入群 — 对接 docs/兴趣社群-老人端群聊-OpenAPI.md
final class InterestCommunityApi {
  InterestCommunityApi._();

  static const String _elderPrefix = '/v1/elder/interest-communities';

  static String _childPrefix(int elderProfileId) =>
      '/v1/child/elders/$elderProfileId/interest-communities';

  /// 静态资源 URL（`/uploads/...`）拼到服务根，不含 `/api`。
  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppConfig.apiBase;
    final origin = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }

  static void _throwIfFail(ApiResponse<dynamic> api) {
    if (!api.isSuccess) throw Exception(api.displayMessage);
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  // —— 老人端：目录 / 成员 ——

  static Future<List<InterestCommunityBrief>> listCommunities() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(_elderPrefix);
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    _throwIfFail(api);
    final list = api.data;
    if (list is! List) return [];
    return list
        .map((e) => InterestCommunityBrief.fromJson(_asMap(e)))
        .toList();
  }

  static Future<Set<String>> loadJoinedCommunityIds() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('$_elderPrefix/memberships');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    _throwIfFail(api);
    final data = api.data;
    if (data == null) return {};
    final ids = data['joinedCommunityIds'] ?? data['joined_community_ids'];
    if (ids is! List) return {};
    return ids.map((e) => '$e').where((e) => e.isNotEmpty).toSet();
  }

  static Future<CommunityJoinResult> joinCommunity(String communityId) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_elderPrefix/memberships',
      data: {'communityId': communityId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    _throwIfFail(api);
    final data = api.data;
    if (data is Map<String, dynamic>) {
      return CommunityJoinResult.fromJson(data);
    }
    return CommunityJoinResult(communityId: communityId);
  }

  static Future<void> leaveCommunity(String communityId) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      '$_elderPrefix/memberships/$communityId',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    _throwIfFail(api);
  }

  static Future<bool> isJoined(String communityId) async {
    final joined = await loadJoinedCommunityIds();
    return joined.contains(communityId);
  }

  // —— 老人端：群消息 ——

  static Future<CommunityMessagePage> listElderMessagesPage(
    String communityId, {
    String? before,
    int limit = 50,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '$_elderPrefix/$communityId/messages',
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': limit,
      },
    );
    return _parseMessagePageResult(res.data);
  }

  /// 拉取当前可见的全部历史（自动翻页，最多 [maxPages] 页）。
  static Future<List<InterestCommunityVoiceMessage>> listElderMessages(
    String communityId, {
    int limit = 50,
    int maxPages = 20,
  }) async {
    final merged = <InterestCommunityVoiceMessage>[];
    final seen = <String>{};
    String? before;
    var hasMore = true;
    var pages = 0;
    while (hasMore && pages < maxPages) {
      final page = await listElderMessagesPage(communityId, before: before, limit: limit);
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

  static Future<InterestCommunityVoiceMessage> sendElderText(
    String communityId, {
    required String textContent,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_elderPrefix/$communityId/messages',
      data: {'kind': 'text', 'textContent': textContent},
    );
    return _parseSingleMessage(res.data);
  }

  static Future<InterestCommunityVoiceMessage> sendElderVoice(
    String communityId, {
    required File file,
    int? durationMs,
  }) async {
    final formData = FormData.fromMap({
      'kind': 'voice',
      if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_elderPrefix/$communityId/messages',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return _parseSingleMessage(res.data);
  }

  static Future<InterestCommunityVoiceMessage> sendElderImage(
    String communityId, {
    required File file,
  }) async {
    final formData = FormData.fromMap({
      'kind': 'image',
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_elderPrefix/$communityId/messages',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return _parseSingleMessage(res.data);
  }

  static Future<void> clearElderChatHistory(String communityId) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      '$_elderPrefix/$communityId/messages',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    _throwIfFail(api);
  }

  // —— 子女端：预览 ——

  static Future<List<ChildCommunityOverviewItem>> listChildOverview(int elderProfileId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      _childPrefix(elderProfileId),
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    _throwIfFail(api);
    final data = api.data;
    if (data == null) return [];
    final communities = data['communities'];
    if (communities is! List) return [];
    final result = <ChildCommunityOverviewItem>[];
    for (final item in communities) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final communityRaw = m['community'];
      if (communityRaw is! Map) continue;
      final latestRaw = m['latestMessage'] ?? m['latest_message'];
      result.add(
        ChildCommunityOverviewItem(
          community: InterestCommunityBrief.fromJson(Map<String, dynamic>.from(communityRaw)),
          joined: m['joined'] == true,
          latestMessage: latestRaw is Map
              ? InterestCommunityVoiceMessage.fromJson(Map<String, dynamic>.from(latestRaw))
              : null,
        ),
      );
    }
    return result;
  }

  static Future<CommunityMessagePage> listChildMessagesPage(
    int elderProfileId,
    String communityId, {
    String? before,
    int limit = 50,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '$_childPrefix(elderProfileId)/$communityId/messages',
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': limit,
      },
    );
    return _parseMessagePageResult(res.data);
  }

  static Future<List<InterestCommunityVoiceMessage>> listChildMessages(
    int elderProfileId,
    String communityId, {
    int limit = 50,
    int maxPages = 20,
  }) async {
    final merged = <InterestCommunityVoiceMessage>[];
    final seen = <String>{};
    String? before;
    var hasMore = true;
    var pages = 0;
    while (hasMore && pages < maxPages) {
      final page = await listChildMessagesPage(
        elderProfileId,
        communityId,
        before: before,
        limit: limit,
      );
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

  static Future<void> clearChildChatHistory(int elderProfileId, String communityId) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      '$_childPrefix(elderProfileId)/$communityId/messages',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    _throwIfFail(api);
  }

  // —— 媒体下载 ——

  static Future<Uint8List> downloadVoiceBytes(String messageId) =>
      CommunityMediaDownloader.downloadVoice(messageId);

  static Future<Uint8List> downloadImageBytes(String messageId) =>
      CommunityMediaDownloader.downloadImage(messageId);

  static CommunityMessagePage _parseMessagePageResult(Map<String, dynamic>? body) {
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    _throwIfFail(api);
    final data = api.data;
    if (data == null) {
      return const CommunityMessagePage(items: [], hasMore: false);
    }
    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .map((e) => InterestCommunityVoiceMessage.fromJson(_asMap(e)))
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
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    _throwIfFail(api);
    final data = api.data;
    if (data == null) throw Exception('发送失败');
    return InterestCommunityVoiceMessage.fromJson(data);
  }
}

/// 子女端父母兴趣社群列表项。
final class ChildCommunityOverviewItem {
  const ChildCommunityOverviewItem({
    required this.community,
    required this.joined,
    this.latestMessage,
  });

  final InterestCommunityBrief community;
  final bool joined;
  final InterestCommunityVoiceMessage? latestMessage;
}
