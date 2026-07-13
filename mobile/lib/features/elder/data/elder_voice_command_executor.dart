import '../../../core/voice/voice_command_models.dart';
import '../../entertainment/data/entertainment_api.dart';
import 'elder_help_service.dart';

abstract final class ElderVoiceCommandExecutor {
  static const EntertainmentMusic _voiceMusic = EntertainmentMusic(
    musicName: '语音点播',
    artist: '语音控制',
    durationSeconds: 0,
    suitableScene: '语音控制',
  );

  static Future<VoiceCommandExecutionResult> execute(
    VoiceCommandMatch match,
  ) async {
    if (!match.isMatched || match.commandType == null) {
      return _result(
        match,
        status: 'failed',
        feedback: '未匹配到标准命令',
      );
    }

    try {
      switch (match.commandType!) {
        case VoiceCommandType.playMusic:
          final music = await _resolveMusicFromVoice(match);
          final task = await EntertainmentApi.playMusic(music);
          return _fromEntertainmentTask(match, task, fallback: '音乐播放命令已发送');
        case VoiceCommandType.dance:
          final music = await _resolveMusicFromVoice(match);
          final task = await EntertainmentApi.startDance(
            music,
            danceMode: 'gentle',
          );
          return _fromEntertainmentTask(match, task, fallback: '跳舞命令已发送');
        case VoiceCommandType.help:
          final help = await ElderHelpService.createHelpRequest(
            triggerMode: 'voice',
          );
          return _result(
            match,
            taskId: '${help.alertId}',
            status: help.status,
            feedback: '已发起语音求助',
          );
        case VoiceCommandType.stop:
          return _result(
            match,
            status: 'degraded',
            feedback: '已识别停止命令，停止接口暂未接入',
          );
      }
    } catch (error) {
      return _result(
        match,
        status: 'failed',
        feedback:
            '后端接口不可用，已降级展示：${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  static Future<EntertainmentMusic> _resolveMusicFromVoice(
    VoiceCommandMatch match,
  ) async {
    try {
      final musicList = await EntertainmentApi.fetchMusic();
      if (musicList.isEmpty) return _voiceMusic;

      final normalizedText = _normalize(match.rawText);
      for (final music in musicList) {
        final normalizedName = _normalize(music.musicName);
        if (normalizedName.isNotEmpty &&
            normalizedText.contains(normalizedName)) {
          return music;
        }
      }

      return musicList.first;
    } catch (_) {
      return _voiceMusic;
    }
  }

  static VoiceCommandExecutionResult _fromEntertainmentTask(
    VoiceCommandMatch match,
    EntertainmentTaskStatus? task, {
    required String fallback,
  }) {
    return _result(
      match,
      taskId: task?.taskId,
      status: task?.status ?? 'sent',
      feedback: task?.message ?? fallback,
    );
  }

  static VoiceCommandExecutionResult _result(
    VoiceCommandMatch match, {
    required String status,
    required String feedback,
    String? taskId,
  }) {
    return VoiceCommandExecutionResult(
      rawText: match.rawText,
      standardCommand: match.standardCommand,
      status: status,
      feedback: feedback,
      taskId: taskId,
      recognizedAt: match.recognizedAt,
    );
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s,，。.!！?？、；;:"“”‘’\-]+'), '');
  }
}
