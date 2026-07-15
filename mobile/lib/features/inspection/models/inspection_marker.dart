import 'dart:convert';

enum InspectionMarkerStatus {
  unhandled,
  handled,
  active,
}

class InspectionMarker {
  const InspectionMarker({
    required this.id,
    required this.type,
    required this.title,
    required this.x,
    required this.y,
    this.level,
    required this.status,
    this.locationName,
    this.elderName,
    this.identitySource,
    this.identityConfidence,
    this.notifiedChild,
    this.imageUrl,
    this.time,
    this.navigationStatus,
    this.obstacleStatus,
    this.description,
    this.message,
    this.handler,
    this.remark,
    this.handleTime,
    this.payloadJson,
  });

  final int id;
  final String type;
  final String title;
  final double x;
  final double y;
  final String? level;
  final InspectionMarkerStatus status;
  final String? locationName;
  final String? elderName;
  final String? identitySource;
  final double? identityConfidence;
  final bool? notifiedChild;
  final String? imageUrl;
  final String? time;
  final String? navigationStatus;
  final String? obstacleStatus;
  final String? description;
  final String? message;
  final String? handler;
  final String? remark;
  final String? handleTime;
  final Map<String, dynamic>? payloadJson;

  bool get isSosAlarm {
    final purpose = payloadJson?['purpose'];
    return type == 'sos' || purpose == 'sos_alarm';
  }

  int? get emergencyAlertId {
    final value = payloadJson?['alertId'] ?? payloadJson?['alert_id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  bool get isEvent =>
      type == 'fall' || type == 'crack' || type == 'obstacle' || isSosAlarm;

  bool get canHandle => isEvent && status == InspectionMarkerStatus.unhandled;

  String get displayMessage {
    final text = description ?? message;
    return text == null || text.trim().isEmpty ? '-' : text;
  }

  InspectionMarker copyWith({
    InspectionMarkerStatus? status,
    String? handler,
    String? remark,
    String? handleTime,
  }) {
    return InspectionMarker(
      id: id,
      type: type,
      title: title,
      x: x,
      y: y,
      level: level,
      status: status ?? this.status,
      locationName: locationName,
      elderName: elderName,
      identitySource: identitySource,
      identityConfidence: identityConfidence,
      notifiedChild: notifiedChild,
      imageUrl: imageUrl,
      time: time,
      navigationStatus: navigationStatus,
      obstacleStatus: obstacleStatus,
      description: description,
      message: message,
      handler: handler ?? this.handler,
      remark: remark ?? this.remark,
      handleTime: handleTime ?? this.handleTime,
      payloadJson: payloadJson,
    );
  }

  factory InspectionMarker.fromJson(Map<String, dynamic> json) {
    return InspectionMarker(
      id: (json['id'] as num).toInt(),
      type: '${json['type']}',
      title: _nullableString(json['title']) ??
          _nullableString(json['description']) ??
          _nullableString(json['message']) ??
          '-',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      level: _nullableString(json['level']),
      status: statusFromJson(json['status']),
      locationName: _nullableString(json['locationName']),
      elderName: _nullableString(json['elderName']),
      identitySource: _nullableString(json['identitySource']),
      identityConfidence: (json['identityConfidence'] as num?)?.toDouble(),
      notifiedChild: json['notifiedChild'] as bool?,
      imageUrl: _nullableString(json['imageUrl']),
      time: _nullableString(json['time']),
      navigationStatus: _nullableString(json['navigationStatus']),
      obstacleStatus: _nullableString(json['obstacleStatus']),
      description: _nullableString(json['description']),
      message: _nullableString(json['message']),
      handler: _nullableString(json['handler']),
      remark: _nullableString(json['remark']),
      handleTime: _nullableString(json['handleTime']),
      payloadJson: _payloadFromJson(json['payloadJson'] ?? json['payload']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'x': x,
      'y': y,
      'level': level,
      'status': statusToJson(status),
      'locationName': locationName,
      'elderName': elderName,
      'identitySource': identitySource,
      'identityConfidence': identityConfidence,
      'notifiedChild': notifiedChild,
      'imageUrl': imageUrl,
      'time': time,
      'navigationStatus': navigationStatus,
      'obstacleStatus': obstacleStatus,
      'description': description,
      'message': message,
      'handler': handler,
      'remark': remark,
      'handleTime': handleTime,
      'payloadJson': payloadJson,
    };
  }

  static InspectionMarkerStatus statusFromJson(Object? value) {
    switch ('$value') {
      case 'handled':
        return InspectionMarkerStatus.handled;
      case 'active':
        return InspectionMarkerStatus.active;
      case 'unhandled':
      default:
        return InspectionMarkerStatus.unhandled;
    }
  }

  static String statusToJson(InspectionMarkerStatus status) {
    switch (status) {
      case InspectionMarkerStatus.handled:
        return 'handled';
      case InspectionMarkerStatus.active:
        return 'active';
      case InspectionMarkerStatus.unhandled:
        return 'unhandled';
    }
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _payloadFromJson(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    final text = _nullableString(value);
    if (text == null) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }
}

class InspectionMapInfo {
  const InspectionMapInfo({
    required this.title,
    required this.width,
    required this.height,
    this.imageAsset,
    this.imageUrl,
  });

  final String title;
  final double width;
  final double height;
  final String? imageAsset;
  final String? imageUrl;

  factory InspectionMapInfo.fromJson(Map<String, dynamic> json) {
    final mapImage = json['mapImage'] as String?;
    return InspectionMapInfo(
      title: json['title'] as String? ??
          json['mapName'] as String? ??
          'Inspection Map',
      width: (json['width'] as num?)?.toDouble() ?? 608,
      height: (json['height'] as num?)?.toDouble() ?? 384,
      imageAsset: json['imageAsset'] as String? ?? _assetFromMapImage(mapImage),
      imageUrl: json['imageUrl'] as String? ?? mapImage,
    );
  }

  static String? _assetFromMapImage(String? mapImage) {
    if (mapImage == null || mapImage.trim().isEmpty) return null;
    if (mapImage.startsWith('assets/')) return mapImage;
    final fileName = mapImage.split('/').where((part) => part.isNotEmpty).last;
    return fileName.isEmpty ? null : 'assets/robot_maps/$fileName';
  }
}

class InspectionNavigationStatus {
  const InspectionNavigationStatus({
    this.taskId,
    this.navigationStatus,
    this.obstacleStatus,
    this.robotX,
    this.robotY,
    this.targetX,
    this.targetY,
    this.targetName,
    this.message,
    this.description,
  });

  final int? taskId;
  final String? navigationStatus;
  final String? obstacleStatus;
  final double? robotX;
  final double? robotY;
  final double? targetX;
  final double? targetY;
  final String? targetName;
  final String? message;
  final String? description;

  String get displayMessage {
    final text = description ?? message;
    return text == null || text.trim().isEmpty ? '-' : text;
  }

  factory InspectionNavigationStatus.fromJson(Map<String, dynamic> json) {
    return InspectionNavigationStatus(
      taskId: _nullableInt(
          json['taskId'] ?? json['navigationTaskId'] ?? json['id']),
      navigationStatus: _nullableString(
        json['navigationStatus'] ?? json['status'],
      ),
      obstacleStatus: _nullableString(json['obstacleStatus']),
      robotX: _nullableDouble(
        json['robotX'] ?? json['currentX'] ?? json['x'],
      ),
      robotY: _nullableDouble(
        json['robotY'] ?? json['currentY'] ?? json['y'],
      ),
      targetX: _nullableDouble(json['targetX']),
      targetY: _nullableDouble(json['targetY']),
      targetName: _nullableString(
        json['targetName'] ?? json['currentTargetName'],
      ),
      message: _nullableString(json['message']),
      description: _nullableString(json['description']),
    );
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}

class InspectionNavigationTask {
  const InspectionNavigationTask({
    required this.id,
    required this.status,
    required this.targetName,
    required this.targetX,
    required this.targetY,
  });

  final int id;
  final String status;
  final String targetName;
  final double targetX;
  final double targetY;

  factory InspectionNavigationTask.fromJson(Map<String, dynamic> json) {
    return InspectionNavigationTask(
      id: _nullableInt(json['id'] ?? json['taskId']) ?? 0,
      status:
          _nullableString(json['status'] ?? json['navigationStatus']) ?? '-',
      targetName: _nullableString(json['targetName']) ?? '导航目标',
      targetX: _nullableDouble(json['targetX']) ?? 0,
      targetY: _nullableDouble(json['targetY']) ?? 0,
    );
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
