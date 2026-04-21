class ElderMedicineProgress {
  const ElderMedicineProgress({
    required this.plannedCount,
    required this.confirmedCount,
    required this.missedCount,
    required this.pendingCount,
    required this.completionPercent,
    required this.activeReminderId,
    required this.medicineName,
    this.doseDesc,
    this.lastConfirmedAt,
    this.nextReminderAt,
  });

  final int plannedCount;
  final int confirmedCount;
  final int missedCount;
  final int pendingCount;
  final double completionPercent;
  final int activeReminderId;
  final String medicineName;
  final String? doseDesc;
  final DateTime? lastConfirmedAt;
  final DateTime? nextReminderAt;

  factory ElderMedicineProgress.fromJson(Map<String, dynamic> json) {
    return ElderMedicineProgress(
      plannedCount: (json['plannedCount'] as num?)?.toInt() ?? 0,
      confirmedCount: (json['confirmedCount'] as num?)?.toInt() ?? 0,
      missedCount: (json['missedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      completionPercent: (json['completionPercent'] as num?)?.toDouble() ?? 0,
      activeReminderId: (json['activeReminderId'] as num?)?.toInt() ?? 0,
      medicineName: json['medicineName']?.toString() ?? '-',
      doseDesc: json['doseDesc']?.toString(),
      lastConfirmedAt: _parseDateTime(json['lastConfirmedAt']?.toString()),
      nextReminderAt: _parseDateTime(json['nextReminderAt']?.toString()),
    );
  }

  ElderMedicineProgress copyWith({
    int? plannedCount,
    int? confirmedCount,
    int? missedCount,
    int? pendingCount,
    double? completionPercent,
    int? activeReminderId,
    String? medicineName,
    String? doseDesc,
    DateTime? lastConfirmedAt,
    DateTime? nextReminderAt,
  }) {
    return ElderMedicineProgress(
      plannedCount: plannedCount ?? this.plannedCount,
      confirmedCount: confirmedCount ?? this.confirmedCount,
      missedCount: missedCount ?? this.missedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      completionPercent: completionPercent ?? this.completionPercent,
      activeReminderId: activeReminderId ?? this.activeReminderId,
      medicineName: medicineName ?? this.medicineName,
      doseDesc: doseDesc ?? this.doseDesc,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      nextReminderAt: nextReminderAt ?? this.nextReminderAt,
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

