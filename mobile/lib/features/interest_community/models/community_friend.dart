/// 可添加的好友候选（演示数据，后续可接后端搜索）。
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
    return ElderFriend(
      scopeKey: '${json['scopeKey']}',
      displayName: '${json['displayName']}',
      phone: '${json['phone']}',
      addedAtMillis: (json['addedAtMillis'] as num?)?.toInt() ?? 0,
      hint: json['hint'] != null ? '${json['hint']}' : '',
      emoji: json['emoji'] != null ? '${json['emoji']}' : '👤',
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
