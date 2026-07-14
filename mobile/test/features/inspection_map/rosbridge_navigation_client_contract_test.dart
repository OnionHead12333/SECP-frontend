import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/data/rosbridge_navigation_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
        '/inspection_map/goal_pose': 'geometry_msgs/msg/PoseStamped',
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
        '/inspection_map/goal_pose': 'geometry_msgs/msg/PoseStamped',
        '/inspection_map/stop_navigation': 'std_msgs/msg/Empty',
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
      client.stopNavigation();

      await server.waitFor(() {
        final initialPoseCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/initialpose',
        ).length;
        final goalPoseCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/inspection_map/goal_pose',
        ).length;
        final stopCount = _messagesFor(
          server.messages,
          op: 'publish',
          topic: '/inspection_map/stop_navigation',
        ).length;
        return initialPoseCount == 1 && goalPoseCount == 1 && stopCount == 1;
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
        topic: '/inspection_map/goal_pose',
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

      final stopMessages = _messagesFor(
        server.messages,
        op: 'publish',
        topic: '/inspection_map/stop_navigation',
      );
      expect(stopMessages, hasLength(1));
      expect(stopMessages.single['msg'], isEmpty);
      expect(
        server.messages.where((message) => message['op'] == 'call_service'),
        isEmpty,
      );
      expect(
        _messagesFor(server.messages, op: 'publish', topic: '/cmd_vel'),
        isEmpty,
      );
    } finally {
      await client.dispose();
      await server.close();
    }
  });

  test('a stale connect failure cannot overwrite the current connection',
      () async {
    final staleReady = Completer<void>();
    late final _FakeWebSocketChannel staleChannel;
    staleChannel = _FakeWebSocketChannel(
      ready: staleReady.future,
      onSinkClose: () {
        if (!staleReady.isCompleted) {
          staleReady.completeError(StateError('stale handshake failed'));
        }
      },
    );
    final currentChannel = _FakeWebSocketChannel(ready: Future<void>.value());
    final requestedUris = <Uri>[];
    final client = RosbridgeNavigationClient(
      channelFactory: (uri) {
        requestedUris.add(uri);
        return uri.host == 'stale' ? staleChannel : currentChannel;
      },
    );
    final events = <RosbridgeConnectionEvent>[];
    final eventSubscription = client.connectionEvents.listen(events.add);

    try {
      final staleConnect = client.connect('ws://stale:9090');
      await _waitFor(() => requestedUris.length == 1);
      final currentConnect = client.connect('ws://current:9090');
      await Future.wait([staleConnect, currentConnect]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('connect futures did not finish'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(requestedUris.map((uri) => uri.host), ['stale', 'current']);
      expect(staleChannel.fakeSink.isClosed, isTrue);
      expect(currentChannel.fakeSink.isClosed, isFalse);
      expect(client.status, RosbridgeConnectionStatus.connected);
      expect(
        events.where(
          (event) => event.status == RosbridgeConnectionStatus.error,
        ),
        isEmpty,
      );
    } finally {
      await eventSubscription.cancel().timeout(
            const Duration(seconds: 2),
            onTimeout: () =>
                throw StateError('event subscription did not cancel'),
          );
      await client.dispose().timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('client did not dispose'),
          );
      await staleChannel.closeIncoming().timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('stale input did not close'),
          );
      await currentChannel.closeIncoming().timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('current input did not close'),
          );
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

Future<void> _waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for test condition');
    }
    await Future<void>.delayed(Duration.zero);
  }
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

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel({
    required this.ready,
    void Function()? onSinkClose,
  }) : fakeSink = _FakeWebSocketSink(onClose: onSinkClose);

  final StreamController<Object?> _incoming =
      StreamController<Object?>.broadcast();

  @override
  final Future<void> ready;

  final _FakeWebSocketSink fakeSink;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  Future<void> closeIncoming() async {
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink({this.onClose});

  final void Function()? onClose;
  final List<Object?> values = [];
  final Completer<void> _done = Completer<void>();
  bool isClosed = false;

  @override
  void add(dynamic data) {
    if (isClosed) throw StateError('WebSocket sink is closed');
    values.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (isClosed) throw StateError('WebSocket sink is closed');
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final value in stream) {
      add(value);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (isClosed) return;
    isClosed = true;
    onClose?.call();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
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
        final message = Map<String, dynamic>.from(decoded);
        messages.add(message);
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
