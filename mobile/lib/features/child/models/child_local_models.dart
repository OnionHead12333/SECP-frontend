/// 子女端本地模型（MVP 前端占位，后续对接接口）。
class BoundElder {
  BoundElder({
    required this.id,
    required this.displayName,
    this.accountHint,
  });

  final String id;
  final String displayName;
  final String? accountHint;
}

class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.elderId,
    required this.name,
    required this.phone,
    required this.priority,
    this.relation,
  });

  final String id;

  /// 所属老人（绑定老人 `BoundElder.id`）
  final String elderId;
  final String name;
  final String phone;

  /// 对应库表 `emergency_contacts.priority`。
  final int priority;
  final String? relation;
}

enum HelpRequestStatus { pending, resolved, cancelled }

class HelpRequestRecord {
  HelpRequestRecord({
    required this.id,
    required this.elderName,
    required this.createdAt,
    required this.summary,
    required this.status,
    this.source,
    this.deviceId,
    this.area,
    this.hardwareMessage,
    this.alertType,
    this.triggerMode,
    this.familyId,
  });

  final String id;
  final String elderName;
  final DateTime createdAt;
  final String summary;
  HelpRequestStatus status;
  final String? source;
  final String? deviceId;
  final String? area;
  final String? hardwareMessage;
  final String? alertType;
  final String? triggerMode;
  final String? familyId;

  bool get isHardwareSos =>
      (source ?? '').trim().toUpperCase() == 'HARDWARE_DEVICE';

  String get displayTitle => isHardwareSos ? '家庭硬件 SOS' : elderName;

  String get displayArea {
    final text = area?.trim();
    return text == null || text.isEmpty ? '家中固定设备区域' : text;
  }

  String get displayHardwareMessage {
    final text = hardwareMessage?.trim();
    return text == null || text.isEmpty ? '家庭硬件 SOS 被触发' : text;
  }
}

class LocationTrackPoint {
  LocationTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String label;
}

class LocationSnapshot {
  LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final String address;
  final DateTime updatedAt;
}

class RoutePoint {
  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class NavigationRouteSnapshot {
  NavigationRouteSnapshot({
    required this.startLabel,
    required this.endLabel,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.statusText,
    required this.points,
  });

  final String startLabel;
  final String endLabel;
  final double distanceKm;
  final int estimatedMinutes;
  final String statusText;
  final List<RoutePoint> points;
}

class ActivitySnapshot {
  ActivitySnapshot({
    required this.stepsToday,
    required this.stateLabel,
    required this.updatedAt,
  });

  final int stepsToday;
  final String stateLabel;
  final DateTime updatedAt;
}
