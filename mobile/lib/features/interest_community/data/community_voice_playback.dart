import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/community_message.dart';
import 'community_media_cache.dart';

/// 群内语音播放：同时只播放一条；优先本机缓存文件。
final class CommunityVoicePlayback {
  CommunityVoicePlayback._();

  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> playingMessageId = ValueNotifier<String?>(null);
  static bool _hooked = false;

  static void _ensureHooked() {
    if (_hooked) return;
    _hooked = true;
    _player.onPlayerComplete.listen((_) {
      playingMessageId.value = null;
    });
  }

  /// 开始/停止播放；无法加载媒体时返回 `false`。
  static Future<bool> toggleMessage(InterestCommunityVoiceMessage message) async {
    _ensureHooked();
    if (playingMessageId.value == message.id) {
      await stop();
      return true;
    }
    final path = await CommunityMediaCache.ensureVoiceFile(message);
    if (path == null || path.isEmpty) return false;
    await toggle(message.id, path);
    return true;
  }

  static Future<void> toggle(String messageId, String path) async {
    _ensureHooked();
    if (playingMessageId.value == messageId) {
      await stop();
      return;
    }
    await stop();
    playingMessageId.value = messageId;
    await _player.play(DeviceFileSource(path));
  }

  static Future<void> stop() async {
    await _player.stop();
    playingMessageId.value = null;
  }

  static Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
