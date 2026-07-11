enum VoiceCommandType {
  stop,
  startPatrol,
  playMusic,
  dance,
  help,
}

extension VoiceCommandTypeX on VoiceCommandType {
  String get backendValue => switch (this) {
        VoiceCommandType.stop => 'stop',
        VoiceCommandType.startPatrol => 'start_patrol',
        VoiceCommandType.playMusic => 'play_music',
        VoiceCommandType.dance => 'dance',
        VoiceCommandType.help => 'help',
      };

  String get label => switch (this) {
        VoiceCommandType.stop => '停止',
        VoiceCommandType.startPatrol => '开始巡检',
        VoiceCommandType.playMusic => '播放音乐',
        VoiceCommandType.dance => '开始表演',
        VoiceCommandType.help => '呼叫帮助',
      };
}

enum VoiceCommandExecutionStatus {
  unmatched,
  matched,
  submitted,
  executed,
  mockOnly,
  backendPending,
  failed,
}

extension VoiceCommandExecutionStatusX on VoiceCommandExecutionStatus {
  String get label => switch (this) {
        VoiceCommandExecutionStatus.unmatched => '未匹配',
        VoiceCommandExecutionStatus.matched => '已识别',
        VoiceCommandExecutionStatus.submitted => '已上报',
        VoiceCommandExecutionStatus.executed => '已执行',
        VoiceCommandExecutionStatus.mockOnly => 'Mock 执行',
        VoiceCommandExecutionStatus.backendPending => '待后端接入',
        VoiceCommandExecutionStatus.failed => '执行失败',
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

class VoiceCommandSubmitResult {
  const VoiceCommandSubmitResult({
    required this.status,
    required this.message,
  });

  final VoiceCommandExecutionStatus status;
  final String message;
}

class VoiceCommandMatch {
  const VoiceCommandMatch({
    required this.rawText,
    required this.recognizedAt,
    required this.status,
    this.commandType,
    this.confidence = 1.0,
    this.matchSource = 'keyword',
    this.detailMessage,
    this.usedMockRecognition = false,
  });

  final String rawText;
  final VoiceCommandType? commandType;
  final double confidence;
  final String matchSource;
  final DateTime recognizedAt;
  final VoiceCommandExecutionStatus status;
  final String? detailMessage;
  final bool usedMockRecognition;

  bool get isMatched => commandType != null;

  String get commandText => commandType?.backendValue ?? 'unmatched';

  VoiceCommandMatch copyWith({
    String? rawText,
    VoiceCommandType? commandType,
    bool clearCommandType = false,
    double? confidence,
    String? matchSource,
    DateTime? recognizedAt,
    VoiceCommandExecutionStatus? status,
    String? detailMessage,
    bool clearDetailMessage = false,
    bool? usedMockRecognition,
  }) {
    return VoiceCommandMatch(
      rawText: rawText ?? this.rawText,
      commandType: clearCommandType ? null : (commandType ?? this.commandType),
      confidence: confidence ?? this.confidence,
      matchSource: matchSource ?? this.matchSource,
      recognizedAt: recognizedAt ?? this.recognizedAt,
      status: status ?? this.status,
      detailMessage:
          clearDetailMessage ? null : (detailMessage ?? this.detailMessage),
      usedMockRecognition: usedMockRecognition ?? this.usedMockRecognition,
    );
  }
}
