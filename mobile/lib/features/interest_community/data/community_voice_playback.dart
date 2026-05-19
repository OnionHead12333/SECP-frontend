import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 群内语音播放：同时只播放一条。
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
