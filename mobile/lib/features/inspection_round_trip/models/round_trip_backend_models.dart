import '../../inspection_map/models/ros_navigation_models.dart';

enum RoundTripCommandMode {
  directRosbridge,
  backendMediated;

  static RoundTripCommandMode parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'direct' || 'direct_rosbridge' || 'directrosbridge' =>
        RoundTripCommandMode.directRosbridge,
      'backend' || 'backend_mediated' || 'backendmediated' =>
        RoundTripCommandMode.backendMediated,
      _ => throw ArgumentError.value(
          value,
          'value',
          'ROUND_TRIP_COMMAND_TRANSPORT 仅支持 direct_rosbridge 或 '
              'backend_mediated。',
        ),
    };
  }

  String get label => switch (this) {
        RoundTripCommandMode.directRosbridge => '直连 rosbridge',
        RoundTripCommandMode.backendMediated => '后端受控',
      };
}

class RoundTripPosePayload {
  const RoundTripPosePayload({
    required this.x,
    required this.y,
    required this.yaw,
    required this.frameId,
    required this.source,
  });

  factory RoundTripPosePayload.fromPose(
    RosPose2D pose, {
    required String source,
  }) {
    return RoundTripPosePayload(
      x: pose.x,
      y: pose.y,
      yaw: pose.yaw,
      frameId: pose.frameId,
      source: source,
    );
  }

  final double x;
  final double y;
  final double yaw;
  final String frameId;
  final String source;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'yaw': yaw,
        'frameId': frameId,
        'source': source,
      };
}

class RoundTripMapPayload {
  const RoundTripMapPayload({
    required this.mapId,
    required this.mapRevision,
    required this.mapName,
    required this.width,
    required this.height,
    required this.resolution,
    required this.origin,
    required this.frameId,
  });

  final int mapId;
  final String mapRevision;
  final String mapName;
  final int width;
  final int height;
  final double resolution;
  final List<double> origin;
  final String frameId;

  Map<String, dynamic> toJson() => {
        'mapId': mapId,
        'mapRevision': mapRevision,
        'mapName': mapName,
        'width': width,
        'height': height,
        'resolution': resolution,
        'origin': origin,
        'frameId': frameId,
      };
}

class RoundTripSubmission {
  const RoundTripSubmission({
    required this.clientRequestId,
    required this.home,
    required this.target,
    required this.map,
    required this.autoReturnDelay,
    required this.createdAt,
  });

  final String clientRequestId;
  final RoundTripPosePayload home;
  final RoundTripPosePayload target;
  final RoundTripMapPayload map;
  final Duration autoReturnDelay;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'clientRequestId': clientRequestId,
        'mapId': map.mapId,
        'mapRevision': map.mapRevision,
        'home': home.toJson(),
        'target': target.toJson(),
        'map': map.toJson(),
        'policy': {
          'autoReturn': true,
          'autoReturnDelayMs': autoReturnDelay.inMilliseconds,
        },
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class BackendRoundTripTaskSnapshot {
  const BackendRoundTripTaskSnapshot({
    required this.taskId,
    required this.status,
    this.outboundGoalId,
    this.returnGoalId,
    this.message,
  });

  final String taskId;
  final String status;
  final String? outboundGoalId;
  final String? returnGoalId;
  final String? message;

  bool get isTerminal => switch (status.toUpperCase()) {
        'COMPLETED' ||
        'CANCELED' ||
        'CANCELLED' ||
        'STOPPED' ||
        'ABORTED' ||
        'FAILED' ||
        'REJECTED' ||
        'STALE' =>
          true,
        _ => false,
      };

  factory BackendRoundTripTaskSnapshot.fromJson(Map<String, dynamic> json) {
    return BackendRoundTripTaskSnapshot(
      taskId: '${json['taskId'] ?? json['id'] ?? ''}',
      status: '${json['status'] ?? 'QUEUED'}',
      outboundGoalId: _stringOrNull(json['outboundGoalId']),
      returnGoalId: _stringOrNull(json['returnGoalId']),
      message: _stringOrNull(json['message']),
    );
  }
}

String? _stringOrNull(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
