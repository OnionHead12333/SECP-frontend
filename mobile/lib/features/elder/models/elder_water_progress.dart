class ElderWaterProgress {
  const ElderWaterProgress({
    required this.plannedCount,
    required this.confirmedCount,
    required this.missedCount,
    required this.pendingCount,
    required this.completionPercent,
    required this.activeReminderId,
    this.lastConfirmedAt,
    this.nextReminderAt,
  });

  final int plannedCount;
  final int confirmedCount;
  final int missedCount;
  final int pendingCount;
  final double completionPercent;
  final int activeReminderId;
  final DateTime? lastConfirmedAt;
  final DateTime? nextReminderAt;

  factory ElderWaterProgress.fromJson(Map<String, dynamic> json) {
    return ElderWaterProgress(
      plannedCount: (json['plannedCount'] as num?)?.toInt() ?? 0,
      confirmedCount: (json['confirmedCount'] as num?)?.toInt() ?? 0,
      missedCount: (json['missedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      completionPercent: (json['completionPercent'] as num?)?.toDouble() ?? 0,
      activeReminderId: (json['activeReminderId'] as num?)?.toInt() ?? 0,
      lastConfirmedAt: _parseDateTime(json['lastConfirmedAt']?.toString()),
      nextReminderAt: _parseDateTime(json['nextReminderAt']?.toString()),
    );
  }

  ElderWaterProgress copyWith({
    int? plannedCount,
    int? confirmedCount,
    int? missedCount,
    int? pendingCount,
    double? completionPercent,
    int? activeReminderId,
    DateTime? lastConfirmedAt,
    DateTime? nextReminderAt,
  }) {
    return ElderWaterProgress(
      plannedCount: plannedCount ?? this.plannedCount,
      confirmedCount: confirmedCount ?? this.confirmedCount,
      missedCount: missedCount ?? this.missedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      completionPercent: completionPercent ?? this.completionPercent,
      activeReminderId: activeReminderId ?? this.activeReminderId,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      nextReminderAt: nextReminderAt ?? this.nextReminderAt,
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
