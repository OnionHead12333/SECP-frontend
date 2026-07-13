import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/data/rosbridge_navigation_client.dart';

void main() {
  test('rosbridge navigation client keeps the ROS WebSocket contract',
      () async {
    final server = await _CaptureRosbridgeServer.start();
    final client = RosbridgeNavigationClient();

    try {
      await client.connect(server.url);

      const subscriptionTypes = <String, String?>{
        '/map': 'nav_msgs/msg/OccupancyGrid',
        '/amcl_pose': 'geometry_msgs/msg/PoseWithCovarianceStamped',
        '/scan': 'sensor_msgs/msg/LaserScan',
        '/plan': 'nav_msgs/msg/Path',
        '/local_plan': 'nav_msgs/msg/Path',
        '/global_costmap/costmap': 'nav_msgs/msg/OccupancyGrid',
        '/local_costmap/costmap': 'nav_msgs/msg/OccupancyGrid',
        '/particlecloud': 'geometry_msgs/msg/PoseArray',
        // The server infers PointCloud or PointCloud2 from the live ROS graph.
        '/cost_cloud': null,
        '/tf': 'tf2_msgs/msg/TFMessage',
        '/tf_static': 'tf2_msgs/msg/TFMessage',
        '/goal_pose': 'geometry_msgs/msg/PoseStamped',
        '/navigate_to_pose/_action/status': 'action_msgs/msg/GoalStatusArray',
        // Foxy generated action topic types are inferred from the ROS graph.
        '/navigate_to_pose/_action/feedback': null,
        '/cmd_vel': 'geometry_msgs/msg/Twist',
      };
      const throttleRates = <String, int>{
        '/amcl_pose': 100,
        '/scan': 160,
        '/plan': 100,
        '/local_plan': 100,
        '/global_costmap/costmap': 900,
        '/local_costmap/costmap': 350,
        '/particlecloud': 350,
        '/cost_cloud': 250,
        '/tf': 50,
        '/navigate_to_pose/_action/feedback': 200,
        '/cmd_vel': 150,
      };
      const advertisementTypes = <String, String>{
        '/initialpose': 'geometry_msgs/msg/PoseWithCovarianceStamped',
        '/goal_pose': 'geometry_msgs/msg/PoseStamped',
        '/cmd_vel': 'geometry_msgs/msg/Twist',
      };

      await server.waitFor(() {
        final subscriptions = server.messages
            .where((message) => message['op'] == 'subscribe')
            .length;
        final advertisements = server.messages
            .where((message) => message['op'] == 'advertise')
            .length;
        return subscriptions == subscriptionTypes.length &&
            advertisements == advertisementTypes.length;
      });

      final subscriptions = server.messages
          .where((message) => message['op'] == 'subscribe')
          .toList(growable: false);
      expect(subscriptions, hasLength(subscriptionTypes.length));
      for (final entry in subscriptionTypes.entries) {
        final subscription = subscriptions.singleWhere(
          (message) => message['topic'] == entry.key,
        );
        expect(subscription['id'], 'inspection-map:${entry.key}');
        if (entry.value == null) {
          expect(subscription.containsKey('type'), isFalse);
        } else {
          expect(subscription['type'], entry.value);
        }
        expect(subscription['queue_length'], 1);
        final throttleRate = throttleRates[entry.key];
        if (throttleRate == null) {
          expect(subscription.containsKey('throttle_rate'), isFalse);
        } else {
          expect(subscription['throttle_rate'], throttleRate);
        }
      }

      final advertisements = server.messages
          .where((message) => message['op'] == 'advertise')
          .toList(growable: false);
      expect(advertisements, hasLength(advertisementTypes.length));
      for (final entry in advertisementTypes.entries) {
        final advertisement = advertisements.singleWhere(
          (message) => message['topic'] == entry.key,
        );
        expect(advertisement['id'], 'inspection-map:advertise:${entry.key}');
        expect(advertisement['type'], entry.value);
      }

      client.publishInitialPose(x: 1.25, y: -2.5, yaw: math.pi / 2);
      client.publishGoalPose(x: -0.75, y: 3.5, yaw: -math.pi / 3);
      await client.cancelNavigationAndStop();

      await server.waitFor(() {
        final initialPoseCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/initialpose',
        ).length;
        final goalPoseCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/goal_pose',
        ).length;
        final cancelCount = server.messages
            .where(
              (message) =>
                  message['op'] == 'call_service' &&
                  message['service'] == '/navigate_to_pose/_action/cancel_goal',
            )
            .length;
        final zeroTwistCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/cmd_vel',
        ).length;
        return initialPoseCount == 1 &&
            goalPoseCount == 1 &&
            cancelCount == 1 &&
            zeroTwistCount == 4;
      });

      final initialPoseEnvelope = _messagesFor(
        server.messages,
        op: 'publish',
        topic: '/initialpose',
      ).single;
      final initialPose = _asMap(initialPoseEnvelope['msg']);
      _expectMapHeader(initialPose);
      final poseWithCovariance = _asMap(initialPose['pose']);
      final initialPoseValue = _asMap(poseWithCovariance['pose']);
      expect(
        _asMap(initialPoseValue['position']),
        equals({'x': 1.25, 'y': -2.5, 'z': 0.0}),
      );
      final initialOrientation = _asMap(initialPoseValue['orientation']);
      expect(initialOrientation['x'], 0.0);
      expect(initialOrientation['y'], 0.0);
      expect(initialOrientation['z'], closeTo(math.sqrt1_2, 1e-12));
      expect(initialOrientation['w'], closeTo(math.sqrt1_2, 1e-12));
      final covariance = _asList(poseWithCovariance['covariance']);
      expect(covariance, hasLength(36));
      for (var index = 0; index < covariance.length; index += 1) {
        final expected = switch (index) {
          0 || 7 => 0.25,
          35 => 0.0685,
          _ => 0,
        };
        expect(covariance[index], expected, reason: 'covariance[$index]');
      }

      final goalPoseEnvelope = _messagesFor(
        server.messages,
        op: 'publish',
        topic: '/goal_pose',
      ).single;
      final goalPose = _asMap(goalPoseEnvelope['msg']);
      _expectMapHeader(goalPose);
      final goalPoseValue = _asMap(goalPose['pose']);
      expect(
        _asMap(goalPoseValue['position']),
        equals({'x': -0.75, 'y': 3.5, 'z': 0.0}),
      );
      final goalOrientation = _asMap(goalPoseValue['orientation']);
      expect(goalOrientation['x'], 0.0);
      expect(goalOrientation['y'], 0.0);
      expect(goalOrientation['z'], closeTo(-0.5, 1e-12));
      expect(goalOrientation['w'], closeTo(math.sqrt(3) / 2, 1e-12));

      final cancelRequest = server.messages.singleWhere(
        (message) =>
            message['op'] == 'call_service' &&
            message['service'] == '/navigate_to_pose/_action/cancel_goal',
      );
      expect(cancelRequest['id'], startsWith('cancel-navigation-'));
      expect(cancelRequest['type'], 'action_msgs/srv/CancelGoal');
      final goalInfo = _asMap(_asMap(cancelRequest['args'])['goal_info']);
      expect(
        _asList(_asMap(goalInfo['goal_id'])['uuid']),
        List<int>.filled(16, 0),
      );
      expect(goalInfo['stamp'], equals({'sec': 0, 'nanosec': 0}));

      const zeroTwist = {
        'linear': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'angular': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      };
      final stopMessages = _messagesFor(
        server.messages,
        op: 'publish',
        topic: '/cmd_vel',
      );
      expect(stopMessages, hasLength(4));
      for (final message in stopMessages) {
        expect(message['msg'], equals(zeroTwist));
      }

      final messageCountAfterStop = server.messages.length;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(
        _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/cmd_vel',
        ),
        hasLength(4),
      );
      expect(server.messages, hasLength(messageCountAfterStop));
    } finally {
      await client.dispose();
      await server.close();
    }
  });
}

List<Map<String, dynamic>> _messagesFor(
  List<Map<String, dynamic>> messages, {
  required String op,
  required String topic,
}) {
  return messages
      .where((message) => message['op'] == op && message['topic'] == topic)
      .toList(growable: false);
}

void _expectMapHeader(Map<String, dynamic> message) {
  final header = _asMap(message['header']);
  expect(header['frame_id'], 'map');
  final stamp = _asMap(header['stamp']);
  expect(stamp['sec'], isA<int>());
  expect(stamp['nanosec'], isA<int>());
  expect(stamp['nanosec'], inInclusiveRange(0, 999999999));
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Object?> _asList(Object? value) {
  return value is List ? List<Object?>.from(value) : const [];
}

class _CaptureRosbridgeServer {
  _CaptureRosbridgeServer._(this._server);

  final HttpServer _server;
  final messages = <Map<String, dynamic>>[];
  final _updates = StreamController<void>.broadcast();
  final _socketCompleter = Completer<WebSocket>();

  String get url => 'ws://${_server.address.address}:${_server.port}';

  static Future<_CaptureRosbridgeServer> start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _CaptureRosbridgeServer._(httpServer);
    httpServer.listen(server._handleRequest);
    return server;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    if (!_socketCompleter.isCompleted) {
      _socketCompleter.complete(socket);
    }
    socket.listen((raw) {
      final payload = raw is List<int> ? utf8.decode(raw) : '$raw';
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        messages.add(Map<String, dynamic>.from(decoded));
        if (!_updates.isClosed) _updates.add(null);
      }
    });
  }

  Future<void> waitFor(bool Function() predicate) async {
    if (predicate()) return;

    final completer = Completer<void>();
    late final StreamSubscription<void> subscription;
    late final Timer timer;

    void completeIfReady() {
      if (!completer.isCompleted && predicate()) completer.complete();
    }

    subscription = _updates.stream.listen((_) => completeIfReady());
    timer = Timer(const Duration(seconds: 4), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Timed out waiting for rosbridge client messages'),
        );
      }
    });
    completeIfReady();

    try {
      await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Future<void> close() async {
    if (_socketCompleter.isCompleted) {
      final socket = await _socketCompleter.future;
      await socket.close();
    }
    await _server.close(force: true);
    await _updates.close();
  }
}
