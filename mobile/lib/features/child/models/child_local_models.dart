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
    this.relation,
  });

  final String id;
  /// 所属老人（绑定老人 `BoundElder.id`）
  final String elderId;
  final String name;
  final String phone;
  final String? relation;
}

enum HelpRequestStatus { pending, resolved }

class HelpRequestRecord {
  HelpRequestRecord({
    required this.id,
    required this.elderName,
    required this.createdAt,
    required this.summary,
    required this.status,
  });

  final String id;
  final String elderName;
  final DateTime createdAt;
  final String summary;
  HelpRequestStatus status;
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
