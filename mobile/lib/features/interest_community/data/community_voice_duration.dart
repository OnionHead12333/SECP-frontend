import 'package:audioplayers/audioplayers.dart';

import '../models/community_message.dart';
import 'community_media_cache.dart';

/// 语音展示时长：优先列表字段，缺失时从已缓存音频文件探测。
abstract final class CommunityVoiceDuration {
  static final Map<String, int> _cacheMs = {};
  static final Map<String, Future<int>> _pending = {};

  static Future<int> resolveMs(InterestCommunityVoiceMessage message) async {
    if (message.durationMs > 0) return message.durationMs;
    final cached = _cacheMs[message.id];
    if (cached != null && cached > 0) return cached;

    return _pending.putIfAbsent(message.id, () async {
      try {
        final path = await CommunityMediaCache.ensureVoiceFile(message);
        if (path == null || path.isEmpty) return 0;
        final ms = await _probeFileMs(path);
        if (ms > 0) _cacheMs[message.id] = ms;
        return ms;
      } finally {
        _pending.remove(message.id);
      }
    });
  }

  static void remember(String messageId, int durationMs) {
    if (durationMs > 0) _cacheMs[messageId] = durationMs;
  }

  static void evictNotIn(Iterable<String> keepMessageIds) {
    final keep = keepMessageIds.toSet();
    _cacheMs.removeWhere((id, _) => !keep.contains(id));
    _pending.removeWhere((id, _) => !keep.contains(id));
  }

  static Future<int> _probeFileMs(String path) async {
    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(path);
      final duration = await player.getDuration();
      return duration?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      await player.dispose();
    }
  }
}
