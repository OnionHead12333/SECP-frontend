import '../../../core/util/api_instant.dart';

class DeviceStatusSnapshot {
  const DeviceStatusSnapshot({
    required this.deviceId,
    this.installArea,
    this.status,
    this.lastHeartbeatAt,
    this.lastSeenAt,
    this.signalStrength,
  });

  final String deviceId;
  final String? installArea;
  final String? status;
  final DateTime? lastHeartbeatAt;
  final DateTime? lastSeenAt;
  final int? signalStrength;

  bool get isOnline {
    final normalized = status?.trim().toLowerCase();
    if (normalized == 'online') return true;
    if (normalized == 'offline') return false;
    final heartbeat = lastHeartbeatAt;
    if (heartbeat == null) return false;
    return DateTime.now().difference(heartbeat) <= const Duration(minutes: 2);
  }

  static DeviceStatusSnapshot fromJson(Map<String, dynamic> json) {
    return DeviceStatusSnapshot(
      deviceId: '${json['deviceId'] ?? json['device_id'] ?? ''}'.trim(),
      installArea: _asString(json['installArea'] ?? json['install_area']),
      status: _asString(json['status']),
      lastHeartbeatAt: parseApiInstantToLocal(
          json['lastHeartbeatAt'] ?? json['last_heartbeat_at']),
      lastSeenAt:
          parseApiInstantToLocal(json['lastSeenAt'] ?? json['last_seen_at']),
      signalStrength: _asInt(json['signalStrength'] ?? json['signal_strength']),
    );
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }
}
