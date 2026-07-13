import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class RosPoint2D {
  const RosPoint2D(this.x, this.y);

  final double x;
  final double y;
}

class RosPose2D {
  const RosPose2D({
    required this.x,
    required this.y,
    required this.yaw,
    this.frameId = 'map',
  });

  final double x;
  final double y;
  final double yaw;
  final String frameId;

  factory RosPose2D.fromPose(
    Map<String, dynamic> pose, {
    String frameId = 'map',
  }) {
    final position = _map(pose['position']);
    final orientation = _map(pose['orientation']);
    return RosPose2D(
      x: _double(position['x']),
      y: _double(position['y']),
      yaw: quaternionYaw(orientation),
      frameId: normalizeRosFrame(frameId),
    );
  }
}

class RosOccupancyGrid {
  const RosOccupancyGrid({
    required this.frameId,
    required this.width,
    required this.height,
    required this.resolution,
    required this.origin,
    required this.data,
  });

  final String frameId;
  final int width;
  final int height;
  final double resolution;
  final RosPose2D origin;
  final List<int> data;

  bool get isValid =>
      width > 0 &&
      height > 0 &&
      resolution > 0 &&
      data.length >= width * height;

  factory RosOccupancyGrid.fromMessage(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final info = _map(message['info']);
    final origin = _map(info['origin']);
    final rawData = message['data'];
    return RosOccupancyGrid(
      frameId: normalizeRosFrame('${header['frame_id'] ?? 'map'}'),
      width: _int(info['width']),
      height: _int(info['height']),
      resolution: _double(info['resolution']),
      origin: RosPose2D.fromPose(
        origin,
        frameId: '${header['frame_id'] ?? 'map'}',
      ),
      data: rawData is List
          ? rawData.map((value) => _int(value)).toList(growable: false)
          : const [],
    );
  }
}

class RosPath {
  const RosPath({required this.frameId, required this.poses});

  final String frameId;
  final List<RosPose2D> poses;

  factory RosPath.fromMessage(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final frameId = normalizeRosFrame('${header['frame_id'] ?? 'map'}');
    final rawPoses = message['poses'];
    return RosPath(
      frameId: frameId,
      poses: rawPoses is List
          ? rawPoses
              .whereType<Map>()
              .map((value) => _map(value))
              .map((value) => RosPose2D.fromPose(
                    _map(value['pose']),
                    frameId: frameId,
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

class RosLaserScan {
  const RosLaserScan({
    required this.frameId,
    required this.angleMin,
    required this.angleIncrement,
    required this.rangeMin,
    required this.rangeMax,
    required this.ranges,
  });

  final String frameId;
  final double angleMin;
  final double angleIncrement;
  final double rangeMin;
  final double rangeMax;
  final List<double> ranges;

  factory RosLaserScan.fromMessage(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final rawRanges = message['ranges'];
    return RosLaserScan(
      frameId: normalizeRosFrame('${header['frame_id'] ?? 'laser'}'),
      angleMin: _double(message['angle_min']),
      angleIncrement: _double(message['angle_increment']),
      rangeMin: _double(message['range_min']),
      rangeMax: _double(message['range_max']),
      ranges: rawRanges is List
          ? rawRanges.map((value) => _double(value)).toList(growable: false)
          : const [],
    );
  }
}

class RosPointCloud {
  const RosPointCloud({required this.frameId, required this.points});

  final String frameId;
  final List<RosPoint2D> points;

  factory RosPointCloud.fromMessage(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final rawPoints = message['points'];
    return RosPointCloud(
      frameId: normalizeRosFrame('${header['frame_id'] ?? 'map'}'),
      points: rawPoints is List
          ? _parsePointCloudPoints(rawPoints)
          : _parsePointCloud2Points(message),
    );
  }
}

List<RosPoint2D> _parsePointCloudPoints(List<dynamic> rawPoints) {
  return rawPoints
      .whereType<Map>()
      .map((value) => _map(value))
      .map((value) => RosPoint2D(
            _double(value['x']),
            _double(value['y']),
          ))
      .toList(growable: false);
}

List<RosPoint2D> _parsePointCloud2Points(Map<String, dynamic> message) {
  final bytes = _pointCloudBytes(message['data']);
  final rawFields = message['fields'];
  final pointStep = _int(message['point_step']);
  if (bytes.isEmpty || rawFields is! List || pointStep <= 0) {
    return const [];
  }

  final fields = rawFields.whereType<Map>().map(_map);
  final xField = fields.where((field) => field['name'] == 'x').firstOrNull;
  final yField = fields.where((field) => field['name'] == 'y').firstOrNull;
  if (xField == null || yField == null) return const [];

  final width = _int(message['width']);
  final declaredHeight = _int(message['height']);
  final height = declaredHeight > 0 ? declaredHeight : 1;
  final pointsPerRow = width > 0 ? width : bytes.length ~/ pointStep;
  final declaredRowStep = _int(message['row_step']);
  final rowStep =
      declaredRowStep > 0 ? declaredRowStep : pointStep * pointsPerRow;
  final endian = message['is_bigendian'] == true ? Endian.big : Endian.little;
  final data = ByteData.sublistView(bytes);
  final points = <RosPoint2D>[];

  for (var row = 0; row < height; row += 1) {
    final rowOffset = row * rowStep;
    for (var column = 0; column < pointsPerRow; column += 1) {
      final pointOffset = rowOffset + column * pointStep;
      final x = _readPointField(data, pointOffset, pointStep, xField, endian);
      final y = _readPointField(data, pointOffset, pointStep, yField, endian);
      if (x != null && y != null && x.isFinite && y.isFinite) {
        points.add(RosPoint2D(x, y));
      }
    }
  }
  return points;
}

Uint8List _pointCloudBytes(Object? value) {
  if (value is String) {
    try {
      return base64Decode(value);
    } on FormatException {
      return Uint8List(0);
    }
  }
  if (value is List) {
    return Uint8List.fromList(
      value.map((byte) => _int(byte) & 0xff).toList(growable: false),
    );
  }
  return Uint8List(0);
}

double? _readPointField(
  ByteData data,
  int pointOffset,
  int pointStep,
  Map<String, dynamic> field,
  Endian endian,
) {
  final fieldOffset = _int(field['offset']);
  final datatype = _int(field['datatype']);
  final size = switch (datatype) {
    1 || 2 => 1,
    3 || 4 => 2,
    5 || 6 || 7 => 4,
    8 => 8,
    _ => 0,
  };
  final offset = pointOffset + fieldOffset;
  if (size == 0 ||
      fieldOffset < 0 ||
      fieldOffset + size > pointStep ||
      offset < 0 ||
      offset + size > data.lengthInBytes) {
    return null;
  }

  return switch (datatype) {
    1 => data.getInt8(offset).toDouble(),
    2 => data.getUint8(offset).toDouble(),
    3 => data.getInt16(offset, endian).toDouble(),
    4 => data.getUint16(offset, endian).toDouble(),
    5 => data.getInt32(offset, endian).toDouble(),
    6 => data.getUint32(offset, endian).toDouble(),
    7 => data.getFloat32(offset, endian),
    8 => data.getFloat64(offset, endian),
    _ => null,
  };
}

class RosPoseArray {
  const RosPoseArray({required this.frameId, required this.poses});

  final String frameId;
  final List<RosPose2D> poses;

  factory RosPoseArray.fromMessage(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final frameId = normalizeRosFrame('${header['frame_id'] ?? 'map'}');
    final rawPoses = message['poses'];
    return RosPoseArray(
      frameId: frameId,
      poses: rawPoses is List
          ? rawPoses
              .whereType<Map>()
              .map((value) => RosPose2D.fromPose(
                    _map(value),
                    frameId: frameId,
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

class RosTransform2D {
  const RosTransform2D({
    required this.parentFrame,
    required this.childFrame,
    required this.x,
    required this.y,
    required this.yaw,
  });

  const RosTransform2D.identity(String frame)
      : parentFrame = frame,
        childFrame = frame,
        x = 0,
        y = 0,
        yaw = 0;

  final String parentFrame;
  final String childFrame;
  final double x;
  final double y;
  final double yaw;

  RosPoint2D transformPoint(RosPoint2D point) {
    final cosine = math.cos(yaw);
    final sine = math.sin(yaw);
    return RosPoint2D(
      x + cosine * point.x - sine * point.y,
      y + sine * point.x + cosine * point.y,
    );
  }

  RosTransform2D compose(RosTransform2D childTransform) {
    final point = transformPoint(
      RosPoint2D(childTransform.x, childTransform.y),
    );
    return RosTransform2D(
      parentFrame: parentFrame,
      childFrame: childTransform.childFrame,
      x: point.x,
      y: point.y,
      yaw: normalizeYaw(yaw + childTransform.yaw),
    );
  }

  factory RosTransform2D.fromStamped(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final transform = _map(message['transform']);
    final translation = _map(transform['translation']);
    final rotation = _map(transform['rotation']);
    return RosTransform2D(
      parentFrame: normalizeRosFrame('${header['frame_id'] ?? ''}'),
      childFrame: normalizeRosFrame('${message['child_frame_id'] ?? ''}'),
      x: _double(translation['x']),
      y: _double(translation['y']),
      yaw: quaternionYaw(rotation),
    );
  }
}

class RosTfTree {
  final Map<String, RosTransform2D> _byChild = {};

  void updateFromMessage(Map<String, dynamic> message) {
    final transforms = message['transforms'];
    if (transforms is! List) return;
    for (final rawTransform in transforms.whereType<Map>()) {
      final transform = RosTransform2D.fromStamped(_map(rawTransform));
      if (transform.parentFrame.isEmpty || transform.childFrame.isEmpty) {
        continue;
      }
      _byChild[transform.childFrame] = transform;
    }
  }

  RosTransform2D? resolve(String fixedFrame, String targetFrame) {
    final fixed = normalizeRosFrame(fixedFrame);
    var current = normalizeRosFrame(targetFrame);
    if (fixed.isEmpty || current.isEmpty) return null;
    if (fixed == current) return RosTransform2D.identity(fixed);

    RosTransform2D? accumulated;
    final visited = <String>{};
    while (current != fixed && visited.add(current)) {
      final edge = _byChild[current];
      if (edge == null) return null;
      accumulated = accumulated == null ? edge : edge.compose(accumulated);
      current = edge.parentFrame;
    }
    return current == fixed ? accumulated : null;
  }
}

enum RosGoalStatus {
  unknown,
  accepted,
  executing,
  canceling,
  succeeded,
  canceled,
  aborted,
}

extension RosGoalStatusLabel on RosGoalStatus {
  String get label => switch (this) {
        RosGoalStatus.unknown => 'idle',
        RosGoalStatus.accepted => 'accepted',
        RosGoalStatus.executing => 'navigating',
        RosGoalStatus.canceling => 'canceling',
        RosGoalStatus.succeeded => 'arrived',
        RosGoalStatus.canceled => 'canceled',
        RosGoalStatus.aborted => 'failed',
      };
}

RosGoalStatus parseGoalStatus(Map<String, dynamic> message) {
  final statuses = message['status_list'];
  if (statuses is! List || statuses.isEmpty) return RosGoalStatus.unknown;
  final latest = _map(statuses.last);
  return switch (_int(latest['status'])) {
    1 => RosGoalStatus.accepted,
    2 => RosGoalStatus.executing,
    3 => RosGoalStatus.canceling,
    4 => RosGoalStatus.succeeded,
    5 => RosGoalStatus.canceled,
    6 => RosGoalStatus.aborted,
    _ => RosGoalStatus.unknown,
  };
}

class RosNavigationFeedback {
  const RosNavigationFeedback({
    required this.currentPose,
    required this.distanceRemaining,
    required this.estimatedTimeRemaining,
    required this.numberOfRecoveries,
  });

  final RosPose2D? currentPose;
  final double distanceRemaining;
  final Duration estimatedTimeRemaining;
  final int numberOfRecoveries;

  factory RosNavigationFeedback.fromMessage(Map<String, dynamic> message) {
    final feedback = _map(message['feedback']);
    final currentPoseStamped = _map(feedback['current_pose']);
    final header = _map(currentPoseStamped['header']);
    final duration = _map(feedback['estimated_time_remaining']);
    final pose = _map(currentPoseStamped['pose']);
    return RosNavigationFeedback(
      currentPose: pose.isEmpty
          ? null
          : RosPose2D.fromPose(
              pose,
              frameId: '${header['frame_id'] ?? 'map'}',
            ),
      distanceRemaining: _double(feedback['distance_remaining']),
      estimatedTimeRemaining: Duration(
        seconds: _int(duration['sec']),
        microseconds: _int(duration['nanosec']) ~/ 1000,
      ),
      numberOfRecoveries: _int(feedback['number_of_recoveries']),
    );
  }
}

double quaternionYaw(Map<String, dynamic> quaternion) {
  final x = _double(quaternion['x']);
  final y = _double(quaternion['y']);
  final z = _double(quaternion['z']);
  final w = _double(quaternion['w'], fallback: 1);
  return math.atan2(
    2 * (w * z + x * y),
    1 - 2 * (y * y + z * z),
  );
}

double normalizeYaw(double yaw) {
  var result = yaw;
  while (result > math.pi) {
    result -= math.pi * 2;
  }
  while (result <= -math.pi) {
    result += math.pi * 2;
  }
  return result;
}

String normalizeRosFrame(String frame) {
  var result = frame.trim();
  while (result.startsWith('/')) {
    result = result.substring(1);
  }
  return result;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

double _double(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
