class ElderLocationGuardSetting {
  const ElderLocationGuardSetting({
    required this.elderProfileId,
    required this.enabled,
    required this.mode,
    required this.intervalSeconds,
    required this.outsideIntervalSeconds,
    required this.backgroundRequired,
    required this.foregroundGranted,
    required this.backgroundGranted,
    required this.batteryOptimizationIgnored,
    this.lastStartedAt,
    this.lastStoppedAt,
    this.lastUploadAt,
    this.lastError,
    this.updatedAt,
  });

  final int elderProfileId;
  final bool enabled;
  final String mode;
  final int intervalSeconds;
  final int outsideIntervalSeconds;
  final bool backgroundRequired;
  final bool foregroundGranted;
  final bool backgroundGranted;
  final bool batteryOptimizationIgnored;
  final DateTime? lastStartedAt;
  final DateTime? lastStoppedAt;
  final DateTime? lastUploadAt;
  final String? lastError;
  final DateTime? updatedAt;

  factory ElderLocationGuardSetting.fromJson(Map<String, dynamic> json) {
    return ElderLocationGuardSetting(
      elderProfileId: (json['elderProfileId'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] == true,
      mode: json['mode']?.toString() ?? 'off',
      intervalSeconds: (json['intervalSeconds'] as num?)?.toInt() ?? 600,
      outsideIntervalSeconds: (json['outsideIntervalSeconds'] as num?)?.toInt() ?? 300,
      backgroundRequired: json['backgroundRequired'] != false,
      foregroundGranted: json['foregroundGranted'] == true,
      backgroundGranted: json['backgroundGranted'] == true,
      batteryOptimizationIgnored: json['batteryOptimizationIgnored'] == true,
      lastStartedAt: _parseDate(json['lastStartedAt']),
      lastStoppedAt: _parseDate(json['lastStoppedAt']),
      lastUploadAt: _parseDate(json['lastUploadAt']),
      lastError: json['lastError']?.toString(),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}
