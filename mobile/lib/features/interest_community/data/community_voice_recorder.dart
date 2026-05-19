import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

final class CommunityVoiceRecordingResult {
  const CommunityVoiceRecordingResult({
    required this.path,
    required this.durationMs,
  });

  final String path;
  final int durationMs;
}

/// 兴趣社群：按住说话，保存为本地 m4a 语音文件。
final class CommunityVoiceRecorder {
  CommunityVoiceRecorder();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  DateTime? _startedAt;

  Future<String?> permissionBlocker() async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) return '请先允许麦克风权限，才能发送语音消息。';
    final ok = await _recorder.hasPermission();
    return ok ? null : '麦克风权限未开启或被系统禁用。';
  }

  Future<void> startRecording() async {
    await cancelRecording();
    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${dir.path}/community_voice');
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }
    _currentPath = '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentPath!,
    );
  }

  Future<CommunityVoiceRecordingResult?> stopRecording() async {
    final started = _startedAt;
    final fallbackPath = _currentPath;
    if (!await _recorder.isRecording().catchError((_) => false)) {
      _resetSession();
      return null;
    }
    final path = await _recorder.stop().catchError((_) => null);
    final resolved = (path != null && path.isNotEmpty) ? path : fallbackPath;
    final durationMs = started == null ? 0 : DateTime.now().difference(started).inMilliseconds;
    _resetSession();
    if (resolved == null || resolved.isEmpty) return null;
    if (!File(resolved).existsSync()) return null;
    if (durationMs < 400) {
      try {
        File(resolved).deleteSync();
      } catch (_) {}
      return null;
    }
    return CommunityVoiceRecordingResult(path: resolved, durationMs: durationMs);
  }

  Future<void> cancelRecording() async {
    if (await _recorder.isRecording().catchError((_) => false)) {
      final path = await _recorder.stop().catchError((_) => null);
      final target = path ?? _currentPath;
      if (target != null) {
        try {
          File(target).deleteSync();
        } catch (_) {}
      }
    }
    _resetSession();
  }

  Future<bool> dispose() async {
    await cancelRecording();
    await _recorder.dispose().catchError((_) {});
    return true;
  }

  void _resetSession() {
    _currentPath = null;
    _startedAt = null;
  }
}
