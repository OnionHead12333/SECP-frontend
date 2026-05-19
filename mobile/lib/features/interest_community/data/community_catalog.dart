import '../models/community_message.dart';

abstract final class CommunityCatalog {
  static const List<InterestCommunityBrief> all = [
    InterestCommunityBrief(
      id: 'taiji',
      name: '太极晨练群',
      shortDescription: '一起练站桩、步法与呼吸节律，互相提醒出门时间。',
      previewIcon: '🥋',
      memberHint: '约 328 人在练',
    ),
    InterestCommunityBrief(
      id: 'calligraphy',
      name: '书法兴趣班',
      shortDescription: '晒作品、聊聊笔墨纸砚，零基础也能练字。',
      previewIcon: '🖌️',
      memberHint: '约 241 人在写',
    ),
    InterestCommunityBrief(
      id: 'fitness',
      name: '健身活力群',
      shortDescription: '散步、徒手操、量力而行的小力量训练。',
      previewIcon: '💪',
      memberHint: '约 417 人在动',
    ),
    InterestCommunityBrief(
      id: 'travel',
      name: '慢旅游分享',
      shortDescription: '交流周边游、跟团游经验，互帮提醒行程与安全。',
      previewIcon: '🧭',
      memberHint: '约 289 人在聊',
    ),
  ];

  static InterestCommunityBrief? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
