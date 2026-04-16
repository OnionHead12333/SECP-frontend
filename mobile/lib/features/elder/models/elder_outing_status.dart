class ElderOutingStatus {
  const ElderOutingStatus({
    required this.locationEnabled,
    required this.monitorStatus,
    required this.currentState,
    this.outsideStartAt,
    this.lastUploadAt,
    this.lastLocationDesc,
  });

  final bool locationEnabled;
  final String monitorStatus;
  final String currentState;
  final DateTime? outsideStartAt;
  final DateTime? lastUploadAt;
  final String? lastLocationDesc;

  factory ElderOutingStatus.fromJson(Map<String, dynamic> json) {
    return ElderOutingStatus(
      locationEnabled: json['locationEnabled'] == true,
      monitorStatus: json['monitorStatus']?.toString() ?? 'normal',
      currentState: json['currentState']?.toString() ?? 'home',
      outsideStartAt: _parseDateTime(json['outsideStartAt']?.toString()),
      lastUploadAt: _parseDateTime(json['lastUploadAt']?.toString()),
      lastLocationDesc: json['lastLocationDesc']?.toString(),
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
