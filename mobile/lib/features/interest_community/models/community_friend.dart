/// 可添加的好友候选（`GET /v1/elder/friends/discover`）。
final class ElderFriendCandidate {
  const ElderFriendCandidate({
    required this.scopeKey,
    required this.displayName,
    required this.phone,
    required this.hint,
    this.emoji = '👤',
  });

  final String scopeKey;
  final String displayName;
  final String phone;
  final String hint;
  final String emoji;

  factory ElderFriendCandidate.fromJson(Map<String, dynamic> json) {
    return ElderFriendCandidate(
      scopeKey: '${json['scopeKey'] ?? json['scope_key'] ?? json['friendScopeKey'] ?? ''}',
      displayName: '${json['displayName'] ?? json['display_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      hint: '${json['hint'] ?? ''}',
      emoji: '${json['emoji'] ?? json['senderEmoji'] ?? json['sender_emoji'] ?? '👤'}',
    );
  }
}

/// 已添加的好友。
final class ElderFriend {
  const ElderFriend({
    required this.scopeKey,
    required this.displayName,
    required this.phone,
    required this.addedAtMillis,
    this.hint = '',
    this.emoji = '👤',
  });

  final String scopeKey;
  final String displayName;
  final String phone;
  final int addedAtMillis;
  final String hint;
  final String emoji;

  factory ElderFriend.fromJson(Map<String, dynamic> json) {
    var addedAtMillis = 0;
    final rawMs = json['addedAtMillis'] ?? json['added_at_millis'];
    if (rawMs is num) {
      addedAtMillis = rawMs.toInt();
    } else {
      final rawAt = json['addedAt'] ?? json['added_at'];
      if (rawAt != null) {
        addedAtMillis = DateTime.tryParse('$rawAt')?.millisecondsSinceEpoch ?? 0;
      }
    }
    return ElderFriend(
      scopeKey: '${json['scopeKey'] ?? json['scope_key'] ?? json['friendScopeKey'] ?? json['friend_scope_key'] ?? ''}',
      displayName: '${json['displayName'] ?? json['display_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      addedAtMillis: addedAtMillis,
      hint: json['hint'] != null ? '${json['hint']}' : '',
      emoji: '${json['emoji'] ?? '👤'}',
    );
  }

  Map<String, dynamic> toJson() => {
        'scopeKey': scopeKey,
        'displayName': displayName,
        'phone': phone,
        'addedAtMillis': addedAtMillis,
        'hint': hint,
        'emoji': emoji,
      };

  ElderFriendCandidate toCandidate() => ElderFriendCandidate(
        scopeKey: scopeKey,
        displayName: displayName,
        phone: phone,
        hint: hint,
        emoji: emoji,
      );
}
