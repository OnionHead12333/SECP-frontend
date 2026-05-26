import '../models/community_join_result.dart';
import 'interest_community_api.dart';

/// 老人兴趣社群入群状态（后端 API）。
abstract final class CommunityMembershipRepository {
  static Future<Set<String>> loadJoinedIds(String scopeKey) async {
    return InterestCommunityApi.loadJoinedCommunityIds();
  }

  static Future<bool> isJoined(String scopeKey, String communityId) async {
    return InterestCommunityApi.isJoined(communityId);
  }

  static Future<CommunityJoinResult> join({
    required String scopeKey,
    required String communityId,
    required String communityName,
  }) async {
    return InterestCommunityApi.joinCommunity(communityId);
  }

  static Future<void> leave(String scopeKey, String communityId) async {
    await InterestCommunityApi.leaveCommunity(communityId);
  }
}
