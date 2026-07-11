import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_matcher.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_models.dart';

void main() {
  group('voice command matcher', () {
    test('maps stop phrases to stop command', () {
      final match = VoiceCommandMatcher.match('请你先停下一下');

      expect(match.commandType, VoiceCommandType.stop);
      expect(match.commandText, 'stop');
      expect(match.status, VoiceCommandExecutionStatus.matched);
    });

    test('maps patrol, music, dance and help phrases', () {
      expect(
        VoiceCommandMatcher.match('去巡逻').commandType,
        VoiceCommandType.startPatrol,
      );
      expect(
        VoiceCommandMatcher.match('来点音乐').commandType,
        VoiceCommandType.playMusic,
      );
      expect(
        VoiceCommandMatcher.match('来个表演').commandType,
        VoiceCommandType.dance,
      );
      expect(
        VoiceCommandMatcher.match('快来帮我').commandType,
        VoiceCommandType.help,
      );
    });

    test('returns unmatched when no keyword is hit', () {
      final match = VoiceCommandMatcher.match('今天天气不错');

      expect(match.commandType, isNull);
      expect(match.status, VoiceCommandExecutionStatus.unmatched);
      expect(match.commandText, 'unmatched');
    });

    test('ignores spacing and punctuation around matched phrases', () {
      final match = VoiceCommandMatcher.match('我想听歌！');

      expect(match.commandType, VoiceCommandType.playMusic);
      expect(match.status, VoiceCommandExecutionStatus.matched);
    });
  });
}
