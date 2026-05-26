import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/community_message.dart';
import 'community_media_downloader.dart';
import 'community_media_load_result.dart';

/// 群聊语音/图片：按需下载、磁盘缓存、内存 Future 去重。
abstract final class CommunityMediaCache {
  static final Map<String, Future<CommunityMediaLoadResult>> _imageLoads = {};
  static final Map<String, Future<String?>> _voiceLoads = {};

  static Future<CommunityMediaLoadResult> loadImage(InterestCommunityVoiceMessage message) {
    return _imageLoads.putIfAbsent(message.id, () => _loadImageImpl(message));
  }

  static Future<String?> ensureVoiceFile(InterestCommunityVoiceMessage message) async {
    return _voiceLoads.putIfAbsent(message.id, () => _loadVoiceImpl(message));
  }

  static void evictNotIn(Iterable<String> keepMessageIds) {
    final keep = keepMessageIds.toSet();
    _imageLoads.removeWhere((id, _) => !keep.contains(id));
    _voiceLoads.removeWhere((id, _) => !keep.contains(id));
  }

  static Future<void> deleteCacheForMessage(String messageId) async {
    _imageLoads.remove(messageId);
    _voiceLoads.remove(messageId);
    final safeId = messageId.replaceAll(RegExp(r'[^\w.-]'), '_');
    final root = await getApplicationDocumentsDirectory();
    for (final kind in ['voice', 'image']) {
      final folder = Directory('${root.path}/community_media_cache/$kind');
      if (!await folder.exists()) continue;
      await for (final entity in folder.list()) {
        if (entity is File && entity.path.contains(safeId)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }

  static Future<void> writeVoicePreview(String messageId, Uint8List bytes) async {
    final path = await _cachedPath('voice', messageId, '.m4a');
    await File(path).writeAsBytes(bytes, flush: true);
    _voiceLoads[messageId] = Future.value(path);
  }

  static Future<CommunityMediaLoadResult> _loadImageImpl(
    InterestCommunityVoiceMessage message,
  ) async {
    if (message.kind != CommunityMessageKind.image) {
      return const CommunityMediaUnavailable('非图片消息');
    }
    try {
      final local = message.imagePath;
      if (local != null && local.isNotEmpty && File(local).existsSync()) {
        final bytes = await File(local).readAsBytes();
        return CommunityMediaReady(bytes: bytes, filePath: local);
      }

      final thumb = message.thumbnailUrl;
      if (thumb != null && thumb.isNotEmpty) {
        try {
          final bytes = await CommunityMediaDownloader.downloadUrlPath(thumb);
          return CommunityMediaReady(bytes: bytes);
        } catch (_) {
          // 缩略图失败则走 messageId 下载
        }
      }

      final ext = CommunityMediaDownloader.fileExtensionForImage(message);
      final cached = await _cachedPath('image', message.id, ext);
      if (File(cached).existsSync()) {
        final bytes = await File(cached).readAsBytes();
        return CommunityMediaReady(bytes: bytes, filePath: cached);
      }

      final bytes = await CommunityMediaDownloader.downloadImage(message.id);
      await File(cached).writeAsBytes(bytes, flush: true);
      return CommunityMediaReady(bytes: bytes, filePath: cached);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      return CommunityMediaUnavailable(msg.isEmpty ? '媒体不可用' : msg);
    }
  }

  static Future<String?> _loadVoiceImpl(InterestCommunityVoiceMessage message) async {
    if (message.kind != CommunityMessageKind.voice) return null;
    try {
      final local = message.audioPath;
      if (local != null && local.isNotEmpty && File(local).existsSync()) {
        return local;
      }

      final ext = CommunityMediaDownloader.fileExtensionForVoice(message);
      final cached = await _cachedPath('voice', message.id, ext);
      if (File(cached).existsSync()) return cached;

      final bytes = await CommunityMediaDownloader.downloadVoice(message.id);
      await File(cached).writeAsBytes(bytes, flush: true);
      return cached;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _cachedPath(String kind, String messageId, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/community_media_cache/$kind');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final safeId = messageId.replaceAll(RegExp(r'[^\w.-]'), '_');
    return '${folder.path}/$safeId$ext';
  }
}
