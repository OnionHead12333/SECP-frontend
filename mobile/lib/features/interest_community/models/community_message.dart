enum InterestCommunityAudience {
  elder,
  child,
}

enum CommunitySenderRole {
  elder,
  child,
}

enum CommunityMessageKind {
  voice,
  text,
}

final class InterestCommunityBrief {
  const InterestCommunityBrief({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.previewIcon,
    this.memberHint = '',
  });

  final String id;
  final String name;
  final String shortDescription;
  final String previewIcon;
  final String memberHint;
}

final class InterestCommunityVoiceMessage {
  InterestCommunityVoiceMessage({
    required this.id,
    required this.communityId,
    required this.role,
    required this.senderDisplay,
    required this.createdAtMillis,
    this.senderScopeKey = '',
    this.kind = CommunityMessageKind.voice,
    this.audioPath,
    this.durationMs = 0,
    this.textContent = '',
  });

  final String id;
  final String communityId;
  final CommunitySenderRole role;
  final String senderDisplay;
  final int createdAtMillis;
  /// 发送者身份 scope，用于老人/子女端判断左右气泡。
  final String senderScopeKey;
  final CommunityMessageKind kind;
  /// 本地语音文件路径（演示环境存于应用文档目录）。
  final String? audioPath;
  final int durationMs;
  /// 纯文字消息（如群欢迎语）；旧版演示数据也可能仅有此字段。
  final String textContent;

  bool get isVoice => kind == CommunityMessageKind.voice && (audioPath?.isNotEmpty ?? false);

  String get displaySummary {
    if (isVoice) return _formatDuration(durationMs);
    final text = textContent.trim();
    if (text.isNotEmpty) return text;
    return '语音消息';
  }

  static String _formatDuration(int ms) {
    final totalSec = (ms / 1000).ceil().clamp(1, 9999);
    if (totalSec < 60) return '$totalSec″';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory InterestCommunityVoiceMessage.fromJson(Map<String, dynamic> json) {
    final roleRaw = '${json['role']}';
    final role = roleRaw == 'child' ? CommunitySenderRole.child : CommunitySenderRole.elder;
    final audioPath = json['audioPath'] as String?;
    final legacyText = '${json['recognizedText'] ?? json['textContent'] ?? ''}';
    final kindRaw = '${json['kind'] ?? ''}';
    final kind = kindRaw == 'text'
        ? CommunityMessageKind.text
        : (audioPath != null && audioPath.isNotEmpty
            ? CommunityMessageKind.voice
            : (legacyText.isNotEmpty ? CommunityMessageKind.text : CommunityMessageKind.voice));

    return InterestCommunityVoiceMessage(
      id: '${json['id']}',
      communityId: '${json['communityId']}',
      role: role,
      senderDisplay: '${json['senderDisplay']}',
      createdAtMillis: (json['createdAtMillis'] as num?)?.toInt() ?? 0,
      senderScopeKey: '${json['senderScopeKey'] ?? ''}',
      kind: kind,
      audioPath: audioPath,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      textContent: legacyText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'communityId': communityId,
        'role': role == CommunitySenderRole.child ? 'child' : 'elder',
        'senderDisplay': senderDisplay,
        'createdAtMillis': createdAtMillis,
        'senderScopeKey': senderScopeKey,
        'kind': kind == CommunityMessageKind.text ? 'text' : 'voice',
        if (audioPath != null) 'audioPath': audioPath,
        'durationMs': durationMs,
        'textContent': textContent,
      };
}
