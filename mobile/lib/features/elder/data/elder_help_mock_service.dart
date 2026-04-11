import '../models/elder_help_request.dart';

final class ElderHelpMockService {
  ElderHelpMockService._();

  static int _nextAlertId = 1000;
  static ElderHelpRequest? _current;

  static Future<ElderHelpRequest> createHelpRequest() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (_current != null && _current!.isPendingRevoke) {
      return _current!;
    }
    final now = DateTime.now();
    _current = ElderHelpRequest(
      alertId: _nextAlertId++,
      status: 'pending_revoke',
      triggerTime: now,
      revokeDeadline: now.add(const Duration(seconds: 5)),
      serverTime: now,
    );
    return _current!;
  }

  static Future<ElderHelpRequest> revokeHelpRequest({
    required int alertId,
    required String cancelMode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final current = _requireCurrent(alertId);
    final now = DateTime.now();
    if (!current.isPendingRevoke ||
        (current.revokeDeadline != null && now.isAfter(current.revokeDeadline!))) {
      throw Exception('撤回时间已过');
    }
    _current = current.copyWith(
      status: 'cancelled',
      cancelTime: now,
      cancelMode: cancelMode,
      serverTime: now,
    );
    return _current!;
  }

  static Future<ElderHelpRequest> sendNow({required int alertId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final current = _requireCurrent(alertId);
    if (!current.isPendingRevoke) {
      throw Exception('当前状态不允许立即发送');
    }
    final now = DateTime.now();
    _current = current.copyWith(
      status: 'sent',
      sentTime: now,
      serverTime: now,
    );
    return _current!;
  }

  static Future<ElderHelpRequest> getHelpRequestStatus({required int alertId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final current = _requireCurrent(alertId);
    final now = DateTime.now();
    if (current.isPendingRevoke && current.revokeDeadline != null && !now.isBefore(current.revokeDeadline!)) {
      _current = current.copyWith(
        status: 'sent',
        sentTime: current.revokeDeadline,
        serverTime: now,
      );
      return _current!;
    }
    _current = current.copyWith(serverTime: now);
    return _current!;
  }

  static ElderHelpRequest _requireCurrent(int alertId) {
    final current = _current;
    if (current == null || current.alertId != alertId) {
      throw Exception('求助记录不存在');
    }
    return current;
  }
}
