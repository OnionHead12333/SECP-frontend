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
  image,
}

final class InterestCommunityBrief {
  const InterestCommunityBrief({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.previewIcon,
    this.memberHint = '',
    this.joined = false,
  });

  final String id;
  final String name;
  final String shortDescription;
  final String previewIcon;
  final String memberHint;
  final bool joined;

  factory InterestCommunityBrief.fromJson(Map<String, dynamic> json) {
    return InterestCommunityBrief(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      shortDescription: '${json['shortDescription'] ?? json['short_description'] ?? ''}',
      previewIcon: '${json['previewIcon'] ?? json['preview_icon'] ?? '💬'}',
      memberHint: '${json['memberHint'] ?? json['member_hint'] ?? ''}',
      joined: json['joined'] == true,
    );
  }
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
    this.audioUrl,
    this.durationMs = 0,
    this.textContent = '',
    this.imagePath,
    this.imageUrl,
    this.thumbnailUrl,
    this.senderAvatarUrl,
    this.senderEmoji,
    this.mine,
  });

  final String id;
  final String communityId;
  final CommunitySenderRole role;
  final String senderDisplay;
  final int createdAtMillis;
  final String senderScopeKey;
  final CommunityMessageKind kind;
  final String? audioPath;
  final String? audioUrl;
  final int durationMs;
  final String textContent;
  final String? imagePath;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? senderAvatarUrl;
  final String? senderEmoji;
  /// 服务端计算；列表接口返回时优先使用。
  final bool? mine;

  bool get isVoice => kind == CommunityMessageKind.voice;

  bool get isImage => kind == CommunityMessageKind.image;

  String get displaySummary {
    if (isVoice) return _formatDuration(durationMs);
    if (isImage) return '[图片]';
    final text = textContent.trim();
    if (text.isNotEmpty) return text;
    return '语音消息';
  }

  static String formatDurationMs(int ms) {
    if (ms <= 0) return '…';
    final totalSec = (ms / 1000).ceil().clamp(1, 9999);
    if (totalSec < 60) return '$totalSec″';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(int ms) => formatDurationMs(ms);

  static int parseDurationMs(Map<String, dynamic> json) {
    final rawMs = json['durationMs'] ?? json['duration_ms'];
    if (rawMs is num && rawMs > 0) return rawMs.toInt();
    if (rawMs is String && rawMs.isNotEmpty) {
      final parsed = int.tryParse(rawMs);
      if (parsed != null && parsed > 0) return parsed;
    }
    final rawSec = json['duration'] ??
        json['durationSeconds'] ??
        json['duration_seconds'] ??
        json['voiceDuration'];
    if (rawSec is num && rawSec > 0) return (rawSec * 1000).toInt();
    return 0;
  }

  factory InterestCommunityVoiceMessage.fromJson(Map<String, dynamic> json) {
    final roleRaw = '${json['role']}';
    final role = roleRaw == 'child' ? CommunitySenderRole.child : CommunitySenderRole.elder;
    final audioPath = json['audioPath'] as String?;
    final audioUrl = json['audioUrl'] as String? ?? json['audio_url'] as String?;
    final imagePath = json['imagePath'] as String?;
    final imageUrl = json['imageUrl'] as String? ?? json['image_url'] as String?;
    final thumbnailUrl =
        json['thumbnailUrl'] as String? ?? json['thumbnail_url'] as String?;
    final legacyText = '${json['recognizedText'] ?? json['textContent'] ?? json['text_content'] ?? ''}';
    final kindRaw = '${json['kind'] ?? ''}';
    final CommunityMessageKind kind;
    if (kindRaw == 'image') {
      kind = CommunityMessageKind.image;
    } else if (kindRaw == 'text') {
      kind = CommunityMessageKind.text;
    } else if (kindRaw == 'voice') {
      kind = CommunityMessageKind.voice;
    } else if (audioUrl != null && audioUrl.isNotEmpty || audioPath != null && audioPath.isNotEmpty) {
      kind = CommunityMessageKind.voice;
    } else if (imageUrl != null && imageUrl.isNotEmpty || imagePath != null && imagePath.isNotEmpty) {
      kind = CommunityMessageKind.image;
    } else {
      kind = legacyText.isNotEmpty ? CommunityMessageKind.text : CommunityMessageKind.voice;
    }

    final created = json['createdAtMillis'] ?? json['created_at_millis'];
    int createdAtMillis = 0;
    if (created is num) {
      createdAtMillis = created.toInt();
    } else if (created is String && created.isNotEmpty) {
      createdAtMillis = DateTime.tryParse(created)?.millisecondsSinceEpoch ?? 0;
    }

    return InterestCommunityVoiceMessage(
      id: '${json['id']}',
      communityId: '${json['communityId'] ?? json['community_id'] ?? ''}',
      role: role,
      senderDisplay: '${json['senderDisplay'] ?? json['sender_display'] ?? json['sender_display_name'] ?? ''}',
      createdAtMillis: createdAtMillis,
      senderScopeKey: '${json['senderScopeKey'] ?? json['sender_scope_key'] ?? ''}',
      kind: kind,
      audioPath: audioPath,
      audioUrl: audioUrl,
      durationMs: parseDurationMs(json),
      textContent: legacyText,
      imagePath: imagePath,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      senderAvatarUrl: json['senderAvatarUrl'] as String? ?? json['sender_avatar_url'] as String?,
      senderEmoji: json['senderEmoji'] as String? ?? json['sender_emoji'] as String?,
      mine: json['mine'] as bool?,
    );
  }

  String get kindJson => switch (kind) {
        CommunityMessageKind.text => 'text',
        CommunityMessageKind.image => 'image',
        CommunityMessageKind.voice => 'voice',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'communityId': communityId,
        'role': role == CommunitySenderRole.child ? 'child' : 'elder',
        'senderDisplay': senderDisplay,
        'createdAtMillis': createdAtMillis,
        'senderScopeKey': senderScopeKey,
        'kind': kindJson,
        if (audioPath != null) 'audioPath': audioPath,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'durationMs': durationMs,
        'textContent': textContent,
        if (imagePath != null) 'imagePath': imagePath,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (senderAvatarUrl != null) 'senderAvatarUrl': senderAvatarUrl,
        if (senderEmoji != null) 'senderEmoji': senderEmoji,
      };
}
