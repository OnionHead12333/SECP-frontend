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
    this.handler,
    this.remark,
    this.handleTime,
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
  final String? handler;
  final String? remark;
  final String? handleTime;

  bool get isEvent => type == 'fall' || type == 'crack' || type == 'obstacle';

  bool get canHandle => isEvent && status == InspectionMarkerStatus.unhandled;

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
      handler: handler ?? this.handler,
      remark: remark ?? this.remark,
      handleTime: handleTime ?? this.handleTime,
    );
  }

  factory InspectionMarker.fromJson(Map<String, dynamic> json) {
    return InspectionMarker(
      id: (json['id'] as num).toInt(),
      type: '${json['type']}',
      title: '${json['title']}',
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
      handler: _nullableString(json['handler']),
      remark: _nullableString(json['remark']),
      handleTime: _nullableString(json['handleTime']),
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
      'handler': handler,
      'remark': remark,
      'handleTime': handleTime,
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
}

class InspectionMapInfo {
  const InspectionMapInfo({
    required this.title,
    required this.width,
    required this.height,
    this.imageUrl,
  });

  final String title;
  final double width;
  final double height;
  final String? imageUrl;

  factory InspectionMapInfo.fromJson(Map<String, dynamic> json) {
    return InspectionMapInfo(
      title: json['title'] as String? ?? '养老院一层地图',
      width: (json['width'] as num?)?.toDouble() ?? 800,
      height: (json['height'] as num?)?.toDouble() ?? 600,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
