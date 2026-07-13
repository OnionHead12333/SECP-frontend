import 'voice_command_models.dart';

abstract final class VoiceCommandMatcher {
  static const List<_VoiceKeywordRule> _rules = [
    _VoiceKeywordRule(
      VoiceCommandType.stop,
      ['停止', '停下', '别动', '停一停', '不要动了'],
    ),
    _VoiceKeywordRule(
      VoiceCommandType.playMusic,
      ['播放音乐', '放音乐', '来点音乐', '放首歌', '播个音乐', '我想听歌'],
    ),
    _VoiceKeywordRule(
      VoiceCommandType.dance,
      ['跳舞', '开始表演', '开始跳舞', '跳一个', '表演一下', '来个表演'],
    ),
    _VoiceKeywordRule(
      VoiceCommandType.help,
      ['求助', 'help', '呼叫帮助', '救命', '帮帮我', '我需要帮助', '叫人来帮我'],
    ),
  ];

  static VoiceCommandMatch match(
    String text, {
    double confidence = 1,
    DateTime? recognizedAt,
    bool usedMockRecognition = false,
  }) {
    final rawText = text.trim();
    final normalized = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[\s,，。.!！?？、；;:"“”‘’\-]+'), '');
    final when = recognizedAt ?? DateTime.now();
    for (final rule in _rules) {
      if (rule.matches(normalized)) {
        return VoiceCommandMatch(
          rawText: rawText,
          commandType: rule.type,
          confidence: confidence,
          recognizedAt: when,
          feedback: '识别为 ${rule.type.backendValue}',
          usedMockRecognition: usedMockRecognition,
        );
      }
    }
    return VoiceCommandMatch(
      rawText: rawText,
      recognizedAt: when,
      feedback: '未匹配到标准命令',
      usedMockRecognition: usedMockRecognition,
    );
  }
}

class _VoiceKeywordRule {
  const _VoiceKeywordRule(this.type, this.keywords);

  final VoiceCommandType type;
  final List<String> keywords;

  bool matches(String normalizedText) {
    if (normalizedText.isEmpty) return false;
    for (final keyword in keywords) {
      if (normalizedText.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }
}
