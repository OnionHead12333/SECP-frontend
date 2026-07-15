import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _mapWidth = 160;
const _mapHeight = 100;
const _resolution = 0.05;
const _originX = -4.0;
const _originY = -2.5;

Future<void> main(List<String> arguments) async {
  final portArgument =
      arguments.where((value) => value.startsWith('--port=')).firstOrNull;
  final port =
      int.tryParse(portArgument?.substring('--port='.length) ?? '') ?? 9090;
  final simulator = _RosbridgeSimulator();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Mock rosbridge listening on ws://127.0.0.1:$port');

  server.listen((request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.upgradeRequired
        ..write('WebSocket endpoint')
        ..close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    simulator.addClient(socket);
  });
}

class _RosbridgeSimulator {
  final clients = <_MockClient>[];
  final random = math.Random(17);
  final startedAt = DateTime.now();

  double robotX = -2.8;
  double robotY = -1.2;
  double robotYaw = 0;
  double goalX = 2.7;
  double goalY = 1.4;
  double goalYaw = 0;
  bool navigating = false;
  int goalStatus = 0;
  int tick = 0;
  List<Map<String, dynamic>> globalPlan = const [];

  _RosbridgeSimulator() {
    globalPlan = _makePlan(robotX, robotY, goalX, goalY, 48);
    Timer.periodic(const Duration(milliseconds: 200), (_) => _update());
  }

  void addClient(WebSocket socket) {
    final client = _MockClient(socket);
    clients.add(client);
    stdout.writeln('Mock rosbridge client connected');
    socket.listen(
      (raw) => _handleMessage(client, '$raw'),
      onDone: () {
        clients.remove(client);
        stdout.writeln('Mock rosbridge client disconnected');
      },
      onError: (_) => clients.remove(client),
    );
  }

  void _handleMessage(_MockClient client, String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    switch (message['op']) {
      case 'subscribe':
        final topic = '${message['topic'] ?? ''}';
        if (topic.isEmpty) return;
        client.subscriptions.add(topic);
        _sendInitialTopic(client, topic);
      case 'unsubscribe':
        client.subscriptions.remove('${message['topic'] ?? ''}');
      case 'publish':
        _handlePublish(
          '${message['topic'] ?? ''}',
          _asMap(message['msg']),
        );
      case 'call_service':
        _handleServiceCall(client, message);
    }
  }

  void _sendInitialTopic(_MockClient client, String topic) {
    switch (topic) {
      case '/map':
        _publishTo(client, topic, _mapMessage());
      case '/global_costmap/costmap':
        _publishTo(client, topic, _globalCostmapMessage());
      case '/local_costmap/costmap':
        _publishTo(client, topic, _localCostmapMessage());
      case '/tf_static':
        _publishTo(client, topic, _staticTfMessage());
      case '/plan':
        _publishTo(client, topic, _pathMessage(globalPlan));
      case '/local_plan':
        _publishTo(client, topic, _pathMessage(_localPlan()));
      case '/inspection_map/goal_pose':
        _publishTo(client, topic, _goalPoseMessage());
      case '/navigate_to_pose/_action/status':
        _publishTo(client, topic, _statusMessage());
    }
  }

  void _handlePublish(String topic, Map<String, dynamic> message) {
    if (topic == '/initialpose') {
      final pose = _asMap(_asMap(message['pose'])['pose']);
      _setRobotPose(pose);
      navigating = false;
      goalStatus = 0;
      _broadcast('/navigate_to_pose/_action/status', _statusMessage());
      return;
    }
    if (topic == '/inspection_map/goal_pose') {
      final pose = _asMap(message['pose']);
      final position = _asMap(pose['position']);
      goalX = _number(position['x']);
      goalY = _number(position['y']);
      goalYaw = _yawFromQuaternion(_asMap(pose['orientation']));
      globalPlan = _makePlan(robotX, robotY, goalX, goalY, 48);
      navigating = true;
      goalStatus = 2;
      _broadcast('/inspection_map/goal_pose', _goalPoseMessage());
      _broadcast('/plan', _pathMessage(globalPlan));
      _broadcast('/navigate_to_pose/_action/status', _statusMessage());
      return;
    }
    if (topic == '/inspection_map/stop_navigation') {
      _cancelNavigation();
      return;
    }
  }

  void _handleServiceCall(_MockClient client, Map<String, dynamic> request) {
    client.socket.add(jsonEncode({
      'op': 'service_response',
      'id': request['id'],
      'service': request['service'],
      'result': false,
      'values': {
        'return_code': 1,
        'message': 'Mock accepts stop only on /inspection_map/stop_navigation',
      },
    }));
  }

  void _cancelNavigation() {
    navigating = false;
    goalStatus = 5;
    _broadcast('/navigate_to_pose/_action/status', _statusMessage());
    _broadcast('/cmd_vel', {
      'linear': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      'angular': {'x': 0.0, 'y': 0.0, 'z': 0.0},
    });
  }

  void _setRobotPose(Map<String, dynamic> pose) {
    final position = _asMap(pose['position']);
    robotX = _number(position['x']);
    robotY = _number(position['y']);
    robotYaw = _yawFromQuaternion(_asMap(pose['orientation']));
  }

  void _update() {
    tick += 1;
    var linearVelocity = 0.0;
    var angularVelocity = 0.0;
    if (navigating) {
      final deltaX = goalX - robotX;
      final deltaY = goalY - robotY;
      final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
      if (distance < 0.07) {
        navigating = false;
        goalStatus = 4;
        robotYaw = goalYaw;
        _broadcast('/navigate_to_pose/_action/status', _statusMessage());
      } else {
        final targetYaw = math.atan2(deltaY, deltaX);
        final yawError = _normalizeYaw(targetYaw - robotYaw);
        angularVelocity = yawError.clamp(-0.8, 0.8);
        robotYaw = _normalizeYaw(robotYaw + angularVelocity * 0.2);
        linearVelocity = 0.24 * math.max(0.25, 1 - yawError.abs());
        final step = math.min(distance, linearVelocity * 0.2);
        robotX += math.cos(robotYaw) * step;
        robotY += math.sin(robotYaw) * step;
      }
    }

    _broadcast('/amcl_pose', _amclPoseMessage());
    _broadcast('/tf', _dynamicTfMessage());
    _broadcast('/scan', _laserScanMessage());
    _broadcast('/particlecloud', _particleCloudMessage());
    _broadcast('/cost_cloud', _costCloudMessage());
    _broadcast('/cmd_vel', {
      'linear': {'x': linearVelocity, 'y': 0.0, 'z': 0.0},
      'angular': {'x': 0.0, 'y': 0.0, 'z': angularVelocity},
    });
    if (navigating) {
      _broadcast('/local_plan', _pathMessage(_localPlan()));
      _broadcast(
        '/navigate_to_pose/_action/feedback',
        _feedbackMessage(),
      );
    }
    if (tick % 5 == 0) {
      _broadcast('/local_costmap/costmap', _localCostmapMessage());
    }
  }

  void _broadcast(String topic, Map<String, dynamic> message) {
    for (final client in List<_MockClient>.from(clients)) {
      if (client.subscriptions.contains(topic)) {
        _publishTo(client, topic, message);
      }
    }
  }

  void _publishTo(
    _MockClient client,
    String topic,
    Map<String, dynamic> message,
  ) {
    client.socket.add(jsonEncode({
      'op': 'publish',
      'topic': topic,
      'msg': message,
    }));
  }

  Map<String, dynamic> _mapMessage() {
    final data = List<int>.filled(_mapWidth * _mapHeight, 0);
    for (var y = 0; y < _mapHeight; y += 1) {
      for (var x = 0; x < _mapWidth; x += 1) {
        final worldX = _originX + x * _resolution;
        final worldY = _originY + y * _resolution;
        final boundary =
            x < 3 || y < 3 || x >= _mapWidth - 3 || y >= _mapHeight - 3;
        final centerWall = worldX > -0.15 && worldX < 0.15 && worldY < 1.15;
        final cabinet =
            worldX > 1.0 && worldX < 1.8 && worldY > -1.8 && worldY < -1.2;
        final unknown = worldX > 2.9 && worldY < -1.7;
        data[y * _mapWidth + x] = unknown
            ? -1
            : boundary || centerWall || cabinet
                ? 100
                : 0;
      }
    }
    return _occupancyGrid(
      width: _mapWidth,
      height: _mapHeight,
      resolution: _resolution,
      originX: _originX,
      originY: _originY,
      data: data,
    );
  }

  Map<String, dynamic> _globalCostmapMessage() {
    final data = List<int>.filled(_mapWidth * _mapHeight, 0);
    for (var y = 0; y < _mapHeight; y += 1) {
      for (var x = 0; x < _mapWidth; x += 1) {
        final worldX = _originX + x * _resolution;
        final worldY = _originY + y * _resolution;
        final distanceToWall = worldX.abs();
        if (worldY < 1.2 && distanceToWall < 0.42) {
          data[y * _mapWidth + x] =
              ((0.42 - distanceToWall) / 0.42 * 100).round();
        }
      }
    }
    return _occupancyGrid(
      width: _mapWidth,
      height: _mapHeight,
      resolution: _resolution,
      originX: _originX,
      originY: _originY,
      data: data,
    );
  }

  Map<String, dynamic> _localCostmapMessage() {
    const width = 72;
    const height = 72;
    const resolution = 0.05;
    final originX = robotX - width * resolution / 2;
    final originY = robotY - height * resolution / 2;
    final data = List<int>.filled(width * height, 0);
    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        final worldX = originX + x * resolution;
        final worldY = originY + y * resolution;
        final obstacleDistance = math.sqrt(
          math.pow(worldX - 1.35, 2) + math.pow(worldY + 1.45, 2),
        );
        if (obstacleDistance < 0.6) {
          data[y * width + x] = ((0.6 - obstacleDistance) / 0.6 * 100).round();
        }
      }
    }
    return _occupancyGrid(
      width: width,
      height: height,
      resolution: resolution,
      originX: originX,
      originY: originY,
      data: data,
    );
  }

  Map<String, dynamic> _occupancyGrid({
    required int width,
    required int height,
    required double resolution,
    required double originX,
    required double originY,
    required List<int> data,
  }) {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'info': {
        'map_load_time': _stamp(),
        'resolution': resolution,
        'width': width,
        'height': height,
        'origin': {
          'position': {'x': originX, 'y': originY, 'z': 0.0},
          'orientation': _quaternion(0),
        },
      },
      'data': data,
    };
  }

  Map<String, dynamic> _amclPoseMessage() {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'pose': {
        'pose': _pose(robotX, robotY, robotYaw),
        'covariance': List<double>.filled(36, 0)
          ..[0] = 0.03
          ..[7] = 0.03
          ..[35] = 0.02,
      },
    };
  }

  Map<String, dynamic> _goalPoseMessage() {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'pose': _pose(goalX, goalY, goalYaw),
    };
  }

  Map<String, dynamic> _pathMessage(List<Map<String, dynamic>> poses) {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'poses': poses
          .map((pose) => {
                'header': {'stamp': _stamp(), 'frame_id': 'map'},
                'pose': pose,
              })
          .toList(growable: false),
    };
  }

  List<Map<String, dynamic>> _localPlan() {
    return _makePlan(robotX, robotY, goalX, goalY, 14);
  }

  List<Map<String, dynamic>> _makePlan(
    double startX,
    double startY,
    double endX,
    double endY,
    int count,
  ) {
    final yaw = math.atan2(endY - startY, endX - startX);
    return List.generate(count, (index) {
      final progress = index / math.max(1, count - 1);
      final bend = math.sin(progress * math.pi) * 0.22;
      return _pose(
        startX + (endX - startX) * progress,
        startY + (endY - startY) * progress + bend,
        yaw,
      );
    });
  }

  Map<String, dynamic> _dynamicTfMessage() {
    return {
      'transforms': [
        {
          'header': {'stamp': _stamp(), 'frame_id': 'map'},
          'child_frame_id': 'base_link',
          'transform': {
            'translation': {'x': robotX, 'y': robotY, 'z': 0.0},
            'rotation': _quaternion(robotYaw),
          },
        },
      ],
    };
  }

  Map<String, dynamic> _staticTfMessage() {
    return {
      'transforms': [
        {
          'header': {'stamp': _stamp(), 'frame_id': 'base_link'},
          'child_frame_id': 'laser',
          'transform': {
            'translation': {'x': 0.12, 'y': 0.0, 'z': 0.25},
            'rotation': _quaternion(0),
          },
        },
      ],
    };
  }

  Map<String, dynamic> _laserScanMessage() {
    const count = 180;
    const angleMin = -math.pi;
    const increment = math.pi * 2 / count;
    final ranges = List<double>.generate(count, (index) {
      final angle = robotYaw + angleMin + increment * index;
      return _rayDistance(robotX, robotY, angle).clamp(0.12, 7.5);
    });
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'laser'},
      'angle_min': angleMin,
      'angle_max': math.pi,
      'angle_increment': increment,
      'time_increment': 0.0,
      'scan_time': 0.2,
      'range_min': 0.12,
      'range_max': 7.5,
      'ranges': ranges,
      'intensities': List<double>.filled(count, 40),
    };
  }

  double _rayDistance(double x, double y, double angle) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    var result = 7.5;
    if (dx.abs() > 0.0001) {
      for (final wallX in [
        _originX + 0.1,
        _originX + _mapWidth * _resolution - 0.1
      ]) {
        final t = (wallX - x) / dx;
        final hitY = y + t * dy;
        if (t > 0 &&
            hitY >= _originY &&
            hitY <= _originY + _mapHeight * _resolution) {
          result = math.min(result, t);
        }
      }
    }
    if (dy.abs() > 0.0001) {
      for (final wallY in [
        _originY + 0.1,
        _originY + _mapHeight * _resolution - 0.1
      ]) {
        final t = (wallY - y) / dy;
        final hitX = x + t * dx;
        if (t > 0 &&
            hitX >= _originX &&
            hitX <= _originX + _mapWidth * _resolution) {
          result = math.min(result, t);
        }
      }
    }
    return result;
  }

  Map<String, dynamic> _particleCloudMessage() {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'poses': List.generate(36, (_) {
        final radius = random.nextDouble() * 0.22;
        final angle = random.nextDouble() * math.pi * 2;
        return _pose(
          robotX + math.cos(angle) * radius,
          robotY + math.sin(angle) * radius,
          robotYaw + (random.nextDouble() - 0.5) * 0.18,
        );
      }),
    };
  }

  Map<String, dynamic> _costCloudMessage() {
    return {
      'header': {'stamp': _stamp(), 'frame_id': 'map'},
      'points': List.generate(28, (index) {
        final angle = index / 28 * math.pi * 2;
        return {
          'x': 1.35 + math.cos(angle) * 0.32,
          'y': -1.45 + math.sin(angle) * 0.32,
          'z': 0.0,
        };
      }),
      'channels': const [],
    };
  }

  Map<String, dynamic> _statusMessage() {
    return {
      'status_list': goalStatus == 0
          ? const []
          : [
              {
                'goal_info': {
                  'goal_id': {'uuid': _goalIdBase64()},
                  'stamp': _stamp(),
                },
                'status': goalStatus,
              },
            ],
    };
  }

  Map<String, dynamic> _feedbackMessage() {
    final distance = math.sqrt(
      math.pow(goalX - robotX, 2) + math.pow(goalY - robotY, 2),
    );
    return {
      'goal_id': {'uuid': _goalIdBase64()},
      'feedback': {
        'current_pose': {
          'header': {'stamp': _stamp(), 'frame_id': 'map'},
          'pose': _pose(robotX, robotY, robotYaw),
        },
        'navigation_time': _duration(DateTime.now().difference(startedAt)),
        'estimated_time_remaining': _duration(
          Duration(milliseconds: (distance / 0.2 * 1000).round()),
        ),
        'number_of_recoveries': 0,
        'distance_remaining': distance,
      },
    };
  }

  String _goalIdBase64() {
    return base64Encode(List<int>.generate(16, (index) => index));
  }

  Map<String, dynamic> _pose(double x, double y, double yaw) {
    return {
      'position': {'x': x, 'y': y, 'z': 0.0},
      'orientation': _quaternion(yaw),
    };
  }

  Map<String, double> _quaternion(double yaw) {
    return {
      'x': 0.0,
      'y': 0.0,
      'z': math.sin(yaw / 2),
      'w': math.cos(yaw / 2),
    };
  }

  Map<String, int> _stamp() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return {
      'sec': micros ~/ Duration.microsecondsPerSecond,
      'nanosec': (micros % Duration.microsecondsPerSecond) * 1000,
    };
  }

  Map<String, int> _duration(Duration duration) {
    return {
      'sec': duration.inSeconds,
      'nanosec': duration.inMicroseconds.remainder(1000000) * 1000,
    };
  }
}

class _MockClient {
  _MockClient(this.socket);

  final WebSocket socket;
  final subscriptions = <String>{};
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

double _yawFromQuaternion(Map<String, dynamic> quaternion) {
  final z = _number(quaternion['z']);
  final w = _number(quaternion['w']);
  return math.atan2(2 * w * z, 1 - 2 * z * z);
}

double _normalizeYaw(double yaw) {
  var result = yaw;
  while (result > math.pi) {
    result -= math.pi * 2;
  }
  while (result <= -math.pi) {
    result += math.pi * 2;
  }
  return result;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
