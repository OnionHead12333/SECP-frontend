import '../models/community_friend.dart';
import 'interest_community_api.dart';

/// 老人好友列表（后端 API，`docs/兴趣社群.md` §11.3）。
abstract final class CommunityFriendRepository {
  static Future<List<ElderFriend>> loadFriends(String ownerScopeKey) {
    return InterestCommunityApi.listFriends();
  }

  static Future<Set<String>> loadFriendScopeKeys(String ownerScopeKey) async {
    final friends = await loadFriends(ownerScopeKey);
    return friends.map((f) => f.scopeKey).toSet();
  }

  static Future<bool> isFriend(String ownerScopeKey, String friendScopeKey) async {
    final keys = await loadFriendScopeKeys(ownerScopeKey);
    return keys.contains(friendScopeKey);
  }

  static Future<bool> isFriendByPhone(String ownerScopeKey, String phone) async {
    final friends = await loadFriends(ownerScopeKey);
    final normalized = phone.trim();
    return friends.any((f) => f.phone == normalized);
  }

  static Future<List<ElderFriendCandidate>> discover({
    String? phone,
  }) {
    return InterestCommunityApi.discoverFriends(phone: phone);
  }

  static Future<ElderFriend> addFriend({
    required String ownerScopeKey,
    required ElderFriendCandidate candidate,
  }) async {
    if (candidate.phone.trim().isNotEmpty) {
      return InterestCommunityApi.addFriend(phone: candidate.phone.trim());
    }
    return InterestCommunityApi.addFriend(scopeKey: candidate.scopeKey);
  }

  static Future<void> removeFriend({
    required String ownerScopeKey,
    required String friendScopeKey,
  }) {
    return InterestCommunityApi.removeFriend(friendScopeKey);
  }
}
