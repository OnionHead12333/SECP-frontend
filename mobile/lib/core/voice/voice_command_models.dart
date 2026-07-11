enum VoiceCommandType {
  stop,
  playMusic,
  dance,
  help,
}

extension VoiceCommandTypeX on VoiceCommandType {
  String get backendValue => switch (this) {
        VoiceCommandType.stop => 'stop',
        VoiceCommandType.playMusic => 'play_music',
        VoiceCommandType.dance => 'dance',
        VoiceCommandType.help => 'help',
      };

  String get label => switch (this) {
        VoiceCommandType.stop => '停止',
        VoiceCommandType.playMusic => '播放音乐',
        VoiceCommandType.dance => '跳舞',
        VoiceCommandType.help => '求助',
      };
}

class VoiceRecognitionResult {
  const VoiceRecognitionResult({
    required this.transcript,
    required this.usedMock,
  });

  final String transcript;
  final bool usedMock;
}

class VoiceCommandMatch {
  const VoiceCommandMatch({
    required this.rawText,
    required this.recognizedAt,
    this.commandType,
    this.confidence = 1,
    this.feedback,
    this.usedMockRecognition = false,
  });

  final String rawText;
  final VoiceCommandType? commandType;
  final DateTime recognizedAt;
  final double confidence;
  final String? feedback;
  final bool usedMockRecognition;

  bool get isMatched => commandType != null;

  String get standardCommand => commandType?.backendValue ?? 'unmatched';

  String get commandLabel => commandType?.label ?? '未匹配';
}

class VoiceCommandExecutionResult {
  const VoiceCommandExecutionResult({
    required this.rawText,
    required this.standardCommand,
    required this.status,
    required this.feedback,
    required this.recognizedAt,
    this.taskId,
  });

  final String rawText;
  final String standardCommand;
  final String status;
  final String feedback;
  final DateTime recognizedAt;
  final String? taskId;
}
