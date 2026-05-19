import '../models/community_friend.dart';

/// 演示：可通过手机号或同群推荐添加的好友目录。
abstract final class FriendDiscoverCatalog {
  static const List<ElderFriendCandidate> all = [
    ElderFriendCandidate(
      scopeKey: 'demo_peer_wang',
      displayName: '王阿姨',
      phone: '13800001101',
      hint: '太极晨练群 · 常约公园晨练',
      emoji: '👵',
    ),
    ElderFriendCandidate(
      scopeKey: 'demo_peer_li',
      displayName: '李叔叔',
      phone: '13800001102',
      hint: '太极晨练群 · 爱聊养生',
      emoji: '👴',
    ),
    ElderFriendCandidate(
      scopeKey: 'demo_peer_zhang',
      displayName: '张大姐',
      phone: '13800001103',
      hint: '书法兴趣班 · 擅长楷书',
      emoji: '👩',
    ),
    ElderFriendCandidate(
      scopeKey: 'demo_peer_zhao',
      displayName: '赵师傅',
      phone: '13800001104',
      hint: '健身活力群 · 每天散步',
      emoji: '🧔',
    ),
    ElderFriendCandidate(
      scopeKey: 'demo_peer_sun',
      displayName: '孙奶奶',
      phone: '13800001105',
      hint: '慢旅游分享 · 周边游达人',
      emoji: '👵',
    ),
  ];

  static ElderFriendCandidate? byPhone(String phone) {
    final normalized = phone.trim();
    for (final c in all) {
      if (c.phone == normalized) return c;
    }
    return null;
  }

  static ElderFriendCandidate? byScopeKey(String scopeKey) {
    for (final c in all) {
      if (c.scopeKey == scopeKey) return c;
    }
    return null;
  }
}
