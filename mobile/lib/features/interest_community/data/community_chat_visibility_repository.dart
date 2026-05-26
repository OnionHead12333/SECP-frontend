import 'package:shared_preferences/shared_preferences.dart';

/// 群聊「清空记录」：按查看者 scope 记录截止时间，仅隐藏此前消息，不删群共享数据。
///
/// 对齐后端规划：每人每群一条 `clear_before_millis`，拉消息时过滤 `createdAtMillis <= clearBefore`。
abstract final class CommunityChatVisibilityRepository {
  static const String _prefsKeyPrefix = 'interest_comm_clear_before_v1_';

  static String _bucket(String viewerScopeKey, String communityId) =>
      '$_prefsKeyPrefix${viewerScopeKey}_$communityId';

  static Future<int?> loadClearBeforeMillis(
    String viewerScopeKey,
    String communityId,
  ) async {
    if (viewerScopeKey.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bucket(viewerScopeKey, communityId));
  }

  /// 将当前时刻设为该用户在本群的「已读清空」分界（此时间及之前的消息对其不可见）。
  static Future<void> hideHistoryBeforeNow(
    String viewerScopeKey,
    String communityId,
  ) async {
    if (viewerScopeKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _bucket(viewerScopeKey, communityId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
