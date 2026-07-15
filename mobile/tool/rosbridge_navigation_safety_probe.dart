import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _defaultUrl = 'ws://127.0.0.1:9090';
const _maximumGoalDistance = 0.20;
const _minimumFrontClearance = 0.35;
const _frontHalfAngle = math.pi / 12;

Future<void> main(List<String> arguments) async {
  late final _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  stdout.writeln('Read-only rosbridge navigation safety probe');
  stdout.writeln('Connecting to ${options.url}');

  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  try {
    socket = await WebSocket.connect(options.url.toString())
        .timeout(const Duration(seconds: 6));
    final collector = _SafetyCollector();
    subscription = socket.listen(
      collector.handleSocketData,
      onError: collector.handleSocketError,
      onDone: collector.handleSocketDone,
      cancelOnError: true,
    );

    for (final entry in _subscriptions.entries) {
      socket.add(jsonEncode({
        'op': 'subscribe',
        'id': 'navigation-safety-probe:${entry.key}',
        'topic': entry.key,
        'type': entry.value,
        'queue_length': 1,
        if (entry.key == '/scan') 'throttle_rate': 100,
      }));
    }

    await collector.coreReady.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw TimeoutException(
        'Timed out waiting for /map, /scan, and /amcl_pose. '
        'Counts: ${collector.messageCounts}',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final connectionFailure = collector.connectionFailure;
    if (connectionFailure != null) throw connectionFailure;

    final result = collector.evaluate(options.distance);
    result.printReport();
    exitCode = result.safe ? 0 : 1;
  } catch (error) {
    stderr.writeln('NAVIGATION_SAFETY_PROBE_ERROR: $error');
    exitCode = 2;
  } finally {
    await subscription?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
  }
}

const _subscriptions = <String, String>{
  '/map': 'nav_msgs/msg/OccupancyGrid',
  '/scan': 'sensor_msgs/msg/LaserScan',
  '/amcl_pose': 'geometry_msgs/msg/PoseWithCovarianceStamped',
  '/navigate_to_pose/_action/status': 'action_msgs/msg/GoalStatusArray',
  '/cmd_vel': 'geometry_msgs/msg/Twist',
};

class _Options {
  const _Options(this.url, this.distance);

  final Uri url;
  final double distance;

  factory _Options.parse(List<String> arguments) {
    if (arguments.length > 2) {
      throw const FormatException(
          'Expected at most a WebSocket URL and distance.');
    }
    final urlText = arguments.isEmpty ? _defaultUrl : arguments.first.trim();
    final url = Uri.tryParse(urlText);
    if (url == null ||
        (url.scheme != 'ws' && url.scheme != 'wss') ||
        url.host.isEmpty) {
      throw FormatException('Invalid rosbridge WebSocket URL: $urlText');
    }
    final distanceText = arguments.length < 2 ? '0.20' : arguments[1].trim();
    final distance = double.tryParse(distanceText);
    if (distance == null ||
        !distance.isFinite ||
        distance <= 0 ||
        distance > _maximumGoalDistance) {
      throw FormatException(
        'Distance must be in (0, $_maximumGoalDistance], got $distanceText.',
      );
    }
    return _Options(url, distance);
  }
}

class _SafetyCollector {
  final messageCounts = <String, int>{};
  final protocolErrors = <String>[];
  final _coreReady = Completer<void>();

  Map<String, dynamic>? _mapMessage;
  Map<String, dynamic>? _scanMessage;
  Map<String, dynamic>? _amclMessage;
  Map<String, dynamic>? _statusMessage;
  Object? connectionFailure;
  int nonZeroCmdVelCount = 0;
  int malformedCmdVelCount = 0;

  Future<void> get coreReady => _coreReady.future;

  void handleSocketData(dynamic raw) {
    try {
      final payload = raw is List<int> ? utf8.decode(raw) : '$raw';
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['op'] != 'publish') {
        final level = '${envelope['level'] ?? ''}'.toLowerCase();
        if (level == 'error' || level == 'fatal') {
          protocolErrors.add('${envelope['msg'] ?? envelope}');
        }
        return;
      }

      final topic = '${envelope['topic'] ?? ''}';
      if (!_subscriptions.containsKey(topic)) return;
      final message = _map(envelope['msg']);
      if (message.isEmpty) {
        protocolErrors.add('$topic delivered a non-object message');
        return;
      }
      messageCounts.update(topic, (count) => count + 1, ifAbsent: () => 1);

      switch (topic) {
        case '/map':
          _mapMessage = message;
        case '/scan':
          _scanMessage = message;
        case '/amcl_pose':
          _amclMessage = message;
        case '/navigate_to_pose/_action/status':
          _statusMessage = message;
        case '/cmd_vel':
          final nonZero = _isNonZeroTwist(message);
          if (nonZero == null) {
            malformedCmdVelCount += 1;
          } else if (nonZero) {
            nonZeroCmdVelCount += 1;
          }
      }
      _completeCoreIfReady();
    } catch (error) {
      protocolErrors.add('Invalid rosbridge message: $error');
    }
  }

  void handleSocketError(Object error, StackTrace stackTrace) {
    connectionFailure = error;
    if (!_coreReady.isCompleted) {
      _coreReady.completeError(error, stackTrace);
    }
  }

  void handleSocketDone() {
    final error = StateError('WebSocket closed during safety observation');
    connectionFailure = error;
    if (!_coreReady.isCompleted) {
      _coreReady.completeError(error);
    }
  }

  void _completeCoreIfReady() {
    if (!_coreReady.isCompleted &&
        _mapMessage != null &&
        _scanMessage != null &&
        _amclMessage != null) {
      _coreReady.complete();
    }
  }

  _SafetyResult evaluate(double distance) {
    final grid = _OccupancyGrid.parse(_mapMessage!);
    final pose = _RobotPose.parse(_amclMessage!);
    if (grid.frameId != pose.frameId) {
      throw StateError(
        'Frame mismatch: map=${grid.frameId}, amcl_pose=${pose.frameId}',
      );
    }

    final goalX = pose.x + math.cos(pose.yaw) * distance;
    final goalY = pose.y + math.sin(pose.yaw) * distance;
    final currentCell = grid.lookup(pose.x, pose.y);
    final goalCell = grid.lookup(goalX, goalY);
    final front = _frontClearance(_scanMessage!);
    final status = _activeStatuses(_statusMessage);

    final reasons = <String>[];
    if (currentCell.occupancy != 0) {
      reasons.add('current occupancy=${currentCell.occupancy}, expected 0');
    }
    if (goalCell.occupancy != 0) {
      reasons.add('goal occupancy=${goalCell.occupancy}, expected 0');
    }
    if (front.minimum < _minimumFrontClearance) {
      reasons.add(
        'front_min=${front.minimum.toStringAsFixed(3)} '
        '< $_minimumFrontClearance',
      );
    }
    if (status.statuses.isNotEmpty) {
      reasons.add('active NavigateToPose status=${status.statuses.join(',')}');
    }
    if (nonZeroCmdVelCount != 0) {
      reasons.add('nonzero /cmd_vel messages=$nonZeroCmdVelCount');
    }
    if (malformedCmdVelCount != 0) {
      reasons.add('malformed /cmd_vel messages=$malformedCmdVelCount');
    }
    if (status.malformed) {
      reasons.add('malformed NavigateToPose status message');
    }
    if (protocolErrors.isNotEmpty) {
      reasons.add('rosbridge errors=${protocolErrors.join(' | ')}');
    }

    return _SafetyResult(
      distance: distance,
      currentX: pose.x,
      currentY: pose.y,
      yaw: pose.yaw,
      currentCell: currentCell,
      goalX: goalX,
      goalY: goalY,
      goalCell: goalCell,
      frontMinimum: front.minimum,
      frontMedian: front.median,
      frontRayCount: front.rayCount,
      finiteFrontSampleCount: front.finiteSampleCount,
      allMinimum: front.allMinimum,
      allRayCount: front.allRayCount,
      finiteAllSampleCount: front.finiteAllSampleCount,
      activeStatuses: status.statuses,
      statusSamples: messageCounts['/navigate_to_pose/_action/status'] ?? 0,
      cmdVelSamples: messageCounts['/cmd_vel'] ?? 0,
      nonZeroCmdVelCount: nonZeroCmdVelCount,
      reasons: reasons,
    );
  }
}

class _OccupancyGrid {
  const _OccupancyGrid({
    required this.frameId,
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.originYaw,
    required this.data,
  });

  final String frameId;
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;
  final double originYaw;
  final List<int> data;

  factory _OccupancyGrid.parse(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final info = _map(message['info']);
    final origin = _map(info['origin']);
    final position = _map(origin['position']);
    final width = _integer(info['width'], 'map width');
    final height = _integer(info['height'], 'map height');
    final resolution = _number(info['resolution'], 'map resolution');
    final rawData = message['data'];
    if (width <= 0 || height <= 0 || resolution <= 0) {
      throw StateError(
          'OccupancyGrid dimensions and resolution must be positive');
    }
    if (rawData is! List || rawData.length < width * height) {
      throw StateError(
        'OccupancyGrid data has ${rawData is List ? rawData.length : 0} cells; '
        'expected ${width * height}',
      );
    }
    return _OccupancyGrid(
      frameId: _frame(header['frame_id']),
      width: width,
      height: height,
      resolution: resolution,
      originX: _number(position['x'], 'map origin x'),
      originY: _number(position['y'], 'map origin y'),
      originYaw: _quaternionYaw(_map(origin['orientation'])),
      data: rawData
          .take(width * height)
          .map((value) => _integer(value, 'map occupancy'))
          .toList(growable: false),
    );
  }

  _GridCell lookup(double worldX, double worldY) {
    final deltaX = worldX - originX;
    final deltaY = worldY - originY;
    final cosine = math.cos(originYaw);
    final sine = math.sin(originYaw);
    final localX = cosine * deltaX + sine * deltaY;
    final localY = -sine * deltaX + cosine * deltaY;
    final x = (localX / resolution).floor();
    final y = (localY / resolution).floor();
    if (x < 0 || y < 0 || x >= width || y >= height) {
      throw StateError(
        'Point (${worldX.toStringAsFixed(6)}, '
        '${worldY.toStringAsFixed(6)}) is outside OccupancyGrid',
      );
    }
    return _GridCell(x, y, data[y * width + x]);
  }
}

class _RobotPose {
  const _RobotPose(this.frameId, this.x, this.y, this.yaw);

  final String frameId;
  final double x;
  final double y;
  final double yaw;

  factory _RobotPose.parse(Map<String, dynamic> message) {
    final header = _map(message['header']);
    final pose = _map(_map(message['pose'])['pose']);
    final position = _map(pose['position']);
    return _RobotPose(
      _frame(header['frame_id']),
      _number(position['x'], 'AMCL x'),
      _number(position['y'], 'AMCL y'),
      _quaternionYaw(_map(pose['orientation'])),
    );
  }
}

class _GridCell {
  const _GridCell(this.x, this.y, this.occupancy);

  final int x;
  final int y;
  final int occupancy;
}

class _ActiveStatusResult {
  const _ActiveStatusResult(this.statuses, this.malformed);

  final List<int> statuses;
  final bool malformed;
}

class _FrontClearance {
  const _FrontClearance({
    required this.minimum,
    required this.median,
    required this.rayCount,
    required this.finiteSampleCount,
    required this.allMinimum,
    required this.allRayCount,
    required this.finiteAllSampleCount,
  });

  final double minimum;
  final double median;
  final int rayCount;
  final int finiteSampleCount;
  final double allMinimum;
  final int allRayCount;
  final int finiteAllSampleCount;
}

class _SafetyResult {
  const _SafetyResult({
    required this.distance,
    required this.currentX,
    required this.currentY,
    required this.yaw,
    required this.currentCell,
    required this.goalX,
    required this.goalY,
    required this.goalCell,
    required this.frontMinimum,
    required this.frontMedian,
    required this.frontRayCount,
    required this.finiteFrontSampleCount,
    required this.allMinimum,
    required this.allRayCount,
    required this.finiteAllSampleCount,
    required this.activeStatuses,
    required this.statusSamples,
    required this.cmdVelSamples,
    required this.nonZeroCmdVelCount,
    required this.reasons,
  });

  final double distance;
  final double currentX;
  final double currentY;
  final double yaw;
  final _GridCell currentCell;
  final double goalX;
  final double goalY;
  final _GridCell goalCell;
  final double frontMinimum;
  final double frontMedian;
  final int frontRayCount;
  final int finiteFrontSampleCount;
  final double allMinimum;
  final int allRayCount;
  final int finiteAllSampleCount;
  final List<int> activeStatuses;
  final int statusSamples;
  final int cmdVelSamples;
  final int nonZeroCmdVelCount;
  final List<String> reasons;

  bool get safe => reasons.isEmpty;

  void printReport() {
    stdout.writeln(
      'current x=${currentX.toStringAsFixed(6)} '
      'y=${currentY.toStringAsFixed(6)} yaw=${yaw.toStringAsFixed(6)} '
      'occupancy=${currentCell.occupancy} '
      'cell=(${currentCell.x},${currentCell.y})',
    );
    stdout.writeln(
      'goal x=${goalX.toStringAsFixed(6)} y=${goalY.toStringAsFixed(6)} '
      'distance=${distance.toStringAsFixed(3)} '
      'occupancy=${goalCell.occupancy} cell=(${goalCell.x},${goalCell.y})',
    );
    stdout.writeln(
      'front_min=${frontMinimum.toStringAsFixed(3)} '
      'front_median=${frontMedian.toStringAsFixed(3)} '
      'front_rays=$frontRayCount finite_front=$finiteFrontSampleCount '
      'required=$_minimumFrontClearance',
    );
    stdout.writeln(
      'all_min=${allMinimum.toStringAsFixed(3)} '
      'all_rays=$allRayCount finite_all=$finiteAllSampleCount',
    );
    stdout.writeln(
      'NavigateToPose status_samples=$statusSamples '
      'active=${activeStatuses.join(',')}',
    );
    stdout.writeln(
      '/cmd_vel samples=$cmdVelSamples nonzero=$nonZeroCmdVelCount',
    );
    if (safe) {
      stdout.writeln('NAVIGATION_SAFETY_PROBE_PASS');
    } else {
      stderr.writeln('NAVIGATION_SAFETY_PROBE_FAIL: ${reasons.join('; ')}');
    }
  }
}

_FrontClearance _frontClearance(Map<String, dynamic> message) {
  final angleMin = _number(message['angle_min'], 'scan angle_min');
  final angleIncrement =
      _number(message['angle_increment'], 'scan angle_increment');
  final rangeMin = _number(message['range_min'], 'scan range_min');
  final rangeMax = _number(message['range_max'], 'scan range_max');
  final ranges = message['ranges'];
  if (angleIncrement == 0 || rangeMin < 0 || rangeMax <= rangeMin) {
    throw StateError('LaserScan angular or range metadata is invalid');
  }
  if (ranges is! List || ranges.isEmpty) {
    throw StateError('LaserScan ranges are empty');
  }

  var frontRayCount = 0;
  var finiteSampleCount = 0;
  var finiteAllSampleCount = 0;
  final clearanceSamples = <double>[];
  final allClearanceSamples = <double>[];
  for (var index = 0; index < ranges.length; index += 1) {
    final angle = _normalizeAngle(angleMin + angleIncrement * index);
    final rawRange = ranges[index];
    double? clearance;
    var finite = false;
    // Foxy rosbridge maps non-finite ROS floats to JSON null.
    if (rawRange == null) {
      clearance = rangeMax;
    } else if (rawRange is num) {
      final value = rawRange.toDouble();
      if (value == double.infinity) {
        clearance = rangeMax;
      } else if (value.isFinite && value >= rangeMin) {
        clearance = math.min(value, rangeMax);
        finite = true;
      }
    }
    if (clearance != null) {
      allClearanceSamples.add(clearance);
      if (finite) finiteAllSampleCount += 1;
    }
    if (angle.abs() > _frontHalfAngle) continue;
    frontRayCount += 1;
    if (clearance != null) {
      clearanceSamples.add(clearance);
      if (finite) finiteSampleCount += 1;
    }
  }
  if (frontRayCount == 0) {
    throw StateError('LaserScan has no rays within +/-15 degrees');
  }
  if (finiteSampleCount == 0) {
    return _FrontClearance(
      minimum: rangeMax,
      median: rangeMax,
      rayCount: frontRayCount,
      finiteSampleCount: 0,
      allMinimum: allClearanceSamples.isEmpty
          ? rangeMax
          : allClearanceSamples.reduce(math.min),
      allRayCount: ranges.length,
      finiteAllSampleCount: finiteAllSampleCount,
    );
  }
  clearanceSamples.sort();
  final middle = clearanceSamples.length ~/ 2;
  final median = clearanceSamples.length.isOdd
      ? clearanceSamples[middle]
      : (clearanceSamples[middle - 1] + clearanceSamples[middle]) / 2;
  return _FrontClearance(
    minimum: clearanceSamples.first,
    median: median,
    rayCount: frontRayCount,
    finiteSampleCount: finiteSampleCount,
    allMinimum: allClearanceSamples.isEmpty
        ? rangeMax
        : allClearanceSamples.reduce(math.min),
    allRayCount: ranges.length,
    finiteAllSampleCount: finiteAllSampleCount,
  );
}

_ActiveStatusResult _activeStatuses(Map<String, dynamic>? message) {
  if (message == null) return const _ActiveStatusResult(<int>[], false);
  final rawStatuses = message['status_list'];
  if (rawStatuses is! List) {
    return const _ActiveStatusResult(<int>[], true);
  }
  final statuses = <int>[];
  var malformed = false;
  for (final rawStatus in rawStatuses) {
    final status = _map(rawStatus)['status'];
    if (status is! num) {
      malformed = true;
      continue;
    }
    final value = status.toInt();
    if (value == 1 || value == 2 || value == 3) statuses.add(value);
  }
  return _ActiveStatusResult(statuses, malformed);
}

bool? _isNonZeroTwist(Map<String, dynamic> message) {
  final linear = _map(message['linear']);
  final angular = _map(message['angular']);
  final values = <Object?>[
    linear['x'],
    linear['y'],
    linear['z'],
    angular['x'],
    angular['y'],
    angular['z'],
  ];
  if (values.any((value) => value is! num || !value.toDouble().isFinite)) {
    return null;
  }
  return values.cast<num>().any((value) => value.abs() > 1e-6);
}

double _quaternionYaw(Map<String, dynamic> quaternion) {
  final x = _number(quaternion['x'], 'quaternion x');
  final y = _number(quaternion['y'], 'quaternion y');
  final z = _number(quaternion['z'], 'quaternion z');
  final w = _number(quaternion['w'], 'quaternion w');
  return math.atan2(
    2 * (w * z + x * y),
    1 - 2 * (y * y + z * z),
  );
}

double _normalizeAngle(double angle) =>
    math.atan2(math.sin(angle), math.cos(angle));

String _frame(Object? value) {
  final frame = '${value ?? ''}'.trim().replaceFirst(RegExp(r'^/+'), '');
  if (frame.isEmpty) throw StateError('ROS frame_id is empty');
  return frame;
}

double _number(Object? value, String label) {
  if (value is! num || !value.toDouble().isFinite) {
    throw StateError('$label is missing or non-finite: $value');
  }
  return value.toDouble();
}

int _integer(Object? value, String label) {
  if (value is! num || !value.toDouble().isFinite) {
    throw StateError('$label is missing or non-finite: $value');
  }
  final integer = value.toInt();
  if (value.toDouble() != integer.toDouble()) {
    throw StateError('$label must be an integer: $value');
  }
  return integer;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

const _usage = '''
Usage:
  dart tool/rosbridge_navigation_safety_probe.dart [ws-url] [distance]

Defaults:
  ws-url   = ws://127.0.0.1:9090
  distance = 0.20

Distance must be greater than 0 and no more than 0.20 metres.
This probe is read-only and only sends rosbridge subscribe operations.
''';
