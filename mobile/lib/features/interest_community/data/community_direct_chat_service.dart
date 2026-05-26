import 'dart:io';

import '../models/community_message.dart';
import '../models/community_message_page.dart';
import 'interest_community_direct_api.dart';

/// 老人私聊读写统一入口。
abstract final class CommunityDirectChatService {
  static Future<CommunityMessagePage> loadMessagesPage({
    required String peerScopeKey,
    String? before,
    int limit = 50,
  }) {
    return InterestCommunityDirectApi.listDirectMessagesPage(
      peerScopeKey,
      before: before,
      limit: limit,
    );
  }

  static Future<List<InterestCommunityVoiceMessage>> loadMessages({
    required String peerScopeKey,
  }) {
    return InterestCommunityDirectApi.listDirectMessages(peerScopeKey);
  }

  static Future<InterestCommunityVoiceMessage> sendText({
    required String peerScopeKey,
    required String textContent,
  }) {
    return InterestCommunityDirectApi.sendDirectText(
      peerScopeKey,
      textContent: textContent,
    );
  }

  static Future<InterestCommunityVoiceMessage> sendVoice({
    required String peerScopeKey,
    required File file,
    int? durationMs,
  }) {
    return InterestCommunityDirectApi.sendDirectVoice(
      peerScopeKey,
      file: file,
      durationMs: durationMs,
    );
  }

  static Future<InterestCommunityVoiceMessage> sendImage({
    required String peerScopeKey,
    required File file,
  }) {
    return InterestCommunityDirectApi.sendDirectImage(peerScopeKey, file: file);
  }

  static Future<void> clearHistory({
    required String peerScopeKey,
  }) {
    return InterestCommunityDirectApi.clearDirectChatHistory(peerScopeKey);
  }
}
