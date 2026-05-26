import 'dart:io';

import '../models/community_message.dart';
import '../models/community_message_page.dart';
import 'interest_community_api.dart';

/// 群聊读写统一入口（老人端 / 子女只读预览）。
abstract final class CommunityGroupChatService {
  static Future<CommunityMessagePage> loadMessagesPage({
    required String communityId,
    required InterestCommunityAudience audience,
    int? elderProfileId,
    String? before,
    int limit = 50,
  }) async {
    if (audience == InterestCommunityAudience.child) {
      if (elderProfileId == null) throw Exception('缺少老人档案 ID');
      return InterestCommunityApi.listChildMessagesPage(
        elderProfileId,
        communityId,
        before: before,
        limit: limit,
      );
    }
    return InterestCommunityApi.listElderMessagesPage(
      communityId,
      before: before,
      limit: limit,
    );
  }

  static Future<List<InterestCommunityVoiceMessage>> loadMessages({
    required String communityId,
    required InterestCommunityAudience audience,
    int? elderProfileId,
  }) async {
    if (audience == InterestCommunityAudience.child) {
      if (elderProfileId == null) throw Exception('缺少老人档案 ID');
      return InterestCommunityApi.listChildMessages(elderProfileId, communityId);
    }
    return InterestCommunityApi.listElderMessages(communityId);
  }

  static Future<InterestCommunityVoiceMessage> sendText({
    required String communityId,
    required String textContent,
  }) async {
    return InterestCommunityApi.sendElderText(communityId, textContent: textContent);
  }

  static Future<InterestCommunityVoiceMessage> sendVoice({
    required String communityId,
    required File file,
    int? durationMs,
  }) async {
    return InterestCommunityApi.sendElderVoice(
      communityId,
      file: file,
      durationMs: durationMs,
    );
  }

  static Future<InterestCommunityVoiceMessage> sendImage({
    required String communityId,
    required File file,
  }) async {
    return InterestCommunityApi.sendElderImage(communityId, file: file);
  }

  static Future<void> clearHistory({
    required String communityId,
    required InterestCommunityAudience audience,
    int? elderProfileId,
  }) async {
    if (audience == InterestCommunityAudience.child) {
      if (elderProfileId == null) throw Exception('缺少老人档案 ID');
      await InterestCommunityApi.clearChildChatHistory(elderProfileId, communityId);
      return;
    }
    await InterestCommunityApi.clearElderChatHistory(communityId);
  }
}
