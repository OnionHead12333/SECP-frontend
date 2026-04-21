class ElderExerciseProgress {
  const ElderExerciseProgress({
    required this.plannedCount,
    required this.completedCount,
    required this.missedCount,
    required this.pendingCount,
    required this.lastCompletionStatus,
    required this.lastCompletionSource,
    required this.activeReminderId,
    this.lastCompletedAt,
  });

  final int plannedCount;
  final int completedCount;
  final int missedCount;
  final int pendingCount;
  final String lastCompletionStatus;
  final String lastCompletionSource;
  final int activeReminderId;
  final DateTime? lastCompletedAt;

  factory ElderExerciseProgress.fromJson(Map<String, dynamic> json) {
    return ElderExerciseProgress(
      plannedCount: (json['plannedCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      missedCount: (json['missedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      lastCompletionStatus: json['lastCompletionStatus']?.toString() ?? 'pending',
      lastCompletionSource: json['lastCompletionSource']?.toString() ?? 'manual',
      activeReminderId: (json['activeReminderId'] as num?)?.toInt() ?? 0,
      lastCompletedAt: _parseDateTime(json['lastCompletedAt']?.toString()),
    );
  }

  ElderExerciseProgress copyWith({
    int? plannedCount,
    int? completedCount,
    int? missedCount,
    int? pendingCount,
    String? lastCompletionStatus,
    String? lastCompletionSource,
    int? activeReminderId,
    DateTime? lastCompletedAt,
  }) {
    return ElderExerciseProgress(
      plannedCount: plannedCount ?? this.plannedCount,
      completedCount: completedCount ?? this.completedCount,
      missedCount: missedCount ?? this.missedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      lastCompletionStatus: lastCompletionStatus ?? this.lastCompletionStatus,
      lastCompletionSource: lastCompletionSource ?? this.lastCompletionSource,
      activeReminderId: activeReminderId ?? this.activeReminderId,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
