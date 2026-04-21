class ElderHelpRequest {
  const ElderHelpRequest({
    required this.alertId,
    required this.status,
    required this.triggerTime,
    this.revokeDeadline,
    this.sentTime,
    this.cancelTime,
    this.cancelMode,
    this.serverTime,
  });

  final int alertId;
  final String status;
  final DateTime triggerTime;
  final DateTime? revokeDeadline;
  final DateTime? sentTime;
  final DateTime? cancelTime;
  final String? cancelMode;
  final DateTime? serverTime;

  bool get isPendingRevoke => status == 'pending_revoke';
  bool get isSent => status == 'sent';
  bool get isCancelled => status == 'cancelled';

  ElderHelpRequest copyWith({
    int? alertId,
    String? status,
    DateTime? triggerTime,
    DateTime? revokeDeadline,
    DateTime? sentTime,
    DateTime? cancelTime,
    String? cancelMode,
    DateTime? serverTime,
    bool clearRevokeDeadline = false,
    bool clearSentTime = false,
    bool clearCancelTime = false,
    bool clearCancelMode = false,
  }) {
    return ElderHelpRequest(
      alertId: alertId ?? this.alertId,
      status: status ?? this.status,
      triggerTime: triggerTime ?? this.triggerTime,
      revokeDeadline: clearRevokeDeadline ? null : (revokeDeadline ?? this.revokeDeadline),
      sentTime: clearSentTime ? null : (sentTime ?? this.sentTime),
      cancelTime: clearCancelTime ? null : (cancelTime ?? this.cancelTime),
      cancelMode: clearCancelMode ? null : (cancelMode ?? this.cancelMode),
      serverTime: serverTime ?? this.serverTime,
    );
  }

  factory ElderHelpRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    return ElderHelpRequest(
      alertId: (json['alertId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending_revoke',
      triggerTime: parseDate(json['triggerTime']) ?? parseDate(json['trigger_time']) ?? DateTime.now(),
      revokeDeadline: parseDate(json['revokeDeadline']) ?? parseDate(json['revoke_deadline']),
      sentTime: parseDate(json['sentTime']) ?? parseDate(json['sent_time']),
      cancelTime: parseDate(json['cancelTime']) ?? parseDate(json['cancel_time']),
      cancelMode: json['cancelMode'] as String? ?? json['cancel_mode'] as String?,
      serverTime: parseDate(json['serverTime']) ?? parseDate(json['server_time']),
    );
  }
}
