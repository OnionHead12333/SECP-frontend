import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/community_message.dart';
import 'interest_community_api.dart';

/// 群聊媒体二进制下载（鉴权走 [ApiClient] 拦截器）。
abstract final class CommunityMediaDownloader {
  static const Duration _mediaTimeout = Duration(minutes: 2);

  static Future<Uint8List> downloadVoice(String messageId) {
    return _downloadBinary('/v1/community-voice/$messageId/file');
  }

  static Future<Uint8List> downloadImage(String messageId) {
    return _downloadBinary('/v1/community-image/$messageId/file');
  }

  /// 缩略图或静态资源路径（带 Bearer）。
  static Future<Uint8List> downloadUrlPath(String urlPath) {
    final full = InterestCommunityApi.resolveMediaUrl(urlPath);
    return _downloadAbsolute(full);
  }

  static Future<Uint8List> _downloadBinary(String apiPath) {
    return _downloadAbsolute(null, apiPath: apiPath);
  }

  static Future<Uint8List> _downloadAbsolute(
    String? absoluteUrl, {
    String? apiPath,
  }) async {
    try {
      final Response<List<int>> res;
      final options = Options(
        responseType: ResponseType.bytes,
        receiveTimeout: _mediaTimeout,
        sendTimeout: _mediaTimeout,
        validateStatus: (code) => code != null && code > 0,
      );
      if (apiPath != null) {
        res = await ApiClient.dio.get<List<int>>(apiPath, options: options);
      } else {
        res = await ApiClient.dio.get<List<int>>(
          absoluteUrl!,
          options: options.copyWith(
            // 绝对 URL 不走 baseUrl 拼接
          ),
        );
      }
      final status = res.statusCode ?? 0;
      final raw = res.data;
      if (status == 200 || status == 206) {
        if (raw == null || raw.isEmpty) throw Exception('媒体为空');
        return Uint8List.fromList(raw);
      }
      throw Exception(_messageFromErrorBody(raw) ?? '媒体不可用 ($status)');
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is List<int>) {
        throw Exception(_messageFromErrorBody(raw) ?? e.message ?? '媒体不可用');
      }
      if (raw is Uint8List) {
        throw Exception(_messageFromErrorBody(raw.toList()) ?? e.message ?? '媒体不可用');
      }
      throw Exception(e.message ?? '媒体不可用');
    }
  }

  static String? _messageFromErrorBody(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final text = utf8.decode(bytes);
      final trimmed = text.trim();
      if (!trimmed.startsWith('{')) return null;
      final map = jsonDecode(trimmed);
      if (map is Map) {
        final msg = map['message'] ?? map['msg'];
        if (msg != null && '$msg'.isNotEmpty) return '$msg';
      }
    } catch (_) {}
    return null;
  }

  static String fileExtensionForVoice(InterestCommunityVoiceMessage message) {
    return _extFromUrl(message.audioUrl, '.m4a');
  }

  static String fileExtensionForImage(InterestCommunityVoiceMessage message) {
    return _extFromUrl(message.imageUrl, '.jpg');
  }

  static String _extFromUrl(String? url, String fallback) {
    if (url == null || url.isEmpty) return fallback;
    final dot = url.lastIndexOf('.');
    if (dot < 0 || dot >= url.length - 1) return fallback;
    final ext = url.substring(dot).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.m4a', '.mp4', '.aac', '.mp3'};
    if (allowed.contains(ext)) return ext;
    return fallback;
  }
}
