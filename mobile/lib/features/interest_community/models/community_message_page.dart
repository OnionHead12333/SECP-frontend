import 'community_message.dart';

/// GET `.../messages` 分页结果。
final class CommunityMessagePage {
  const CommunityMessagePage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
  });

  final List<InterestCommunityVoiceMessage> items;
  final bool hasMore;
  final String? nextBefore;
}
