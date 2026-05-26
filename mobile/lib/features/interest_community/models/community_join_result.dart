/// POST `.../memberships` 入群成功后的返回摘要。
final class CommunityJoinResult {
  const CommunityJoinResult({
    required this.communityId,
    this.scopeKey,
    this.welcomeMessage,
  });

  final String communityId;
  final String? scopeKey;
  /// 群助手欢迎语；仅入群瞬间用于弹窗/顶部提示，不依赖消息列表。
  final String? welcomeMessage;

  factory CommunityJoinResult.fromJson(Map<String, dynamic> json) {
    final welcome = json['welcomeMessage'] ??
        json['welcome_message'] ??
        (json['welcome'] is Map
            ? (json['welcome'] as Map)['message'] ?? (json['welcome'] as Map)['text']
            : null);
    return CommunityJoinResult(
      communityId: '${json['communityId'] ?? json['community_id'] ?? ''}',
      scopeKey: json['scopeKey'] as String? ?? json['scope_key'] as String?,
      welcomeMessage: welcome != null && '$welcome'.trim().isNotEmpty ? '$welcome'.trim() : null,
    );
  }
}
