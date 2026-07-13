import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

enum RosbridgeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class RosbridgeConnectionEvent {
  const RosbridgeConnectionEvent(this.status, {this.message});

  final RosbridgeConnectionStatus status;
  final String? message;
}

class RosbridgeTopicMessage {
  const RosbridgeTopicMessage({required this.topic, required this.message});

  final String topic;
  final Map<String, dynamic> message;
}

class RosbridgeNavigationClient {
  final _connectionController =
      StreamController<RosbridgeConnectionEvent>.broadcast();
  final _messageController =
      StreamController<RosbridgeTopicMessage>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _socketSubscription;
  Timer? _reconnectTimer;
  String? _url;
  bool _manualDisconnect = true;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  RosbridgeConnectionStatus _status = RosbridgeConnectionStatus.disconnected;

  Stream<RosbridgeConnectionEvent> get connectionEvents =>
      _connectionController.stream;

  Stream<RosbridgeTopicMessage> get messages => _messageController.stream;

  RosbridgeConnectionStatus get status => _status;

  Future<void> connect(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('ROS bridge URL is empty');
    }

    _manualDisconnect = false;
    _url = trimmedUrl;
    _reconnectTimer?.cancel();
    await _closeSocket();
    _emitConnection(
      _reconnectAttempt == 0
          ? RosbridgeConnectionStatus.connecting
          : RosbridgeConnectionStatus.reconnecting,
    );

    try {
      final channel = WebSocketChannel.connect(Uri.parse(trimmedUrl));
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 6));
      if (_disposed || _manualDisconnect || _channel != channel) {
        await channel.sink.close(ws_status.normalClosure);
        return;
      }

      _reconnectAttempt = 0;
      _emitConnection(RosbridgeConnectionStatus.connected);
      _socketSubscription = channel.stream.listen(
        _handleSocketData,
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketClosed('WebSocket error: $error');
        },
        onDone: () {
          _handleSocketClosed('WebSocket closed');
        },
        cancelOnError: true,
      );
      _registerRosInterfaces();
    } catch (error) {
      _emitConnection(
        RosbridgeConnectionStatus.error,
        message: '$error',
      );
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _closeSocket();
    _emitConnection(RosbridgeConnectionStatus.disconnected);
  }

  void publishInitialPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    final quaternion = _yawQuaternion(yaw);
    _publish('/initialpose', {
      'header': {
        'stamp': _rosTimeNow(),
        'frame_id': 'map',
      },
      'pose': {
        'pose': {
          'position': {'x': x, 'y': y, 'z': 0.0},
          'orientation': quaternion,
        },
        'covariance': const [
          0.25,
          0,
          0,
          0,
          0,
          0,
          0,
          0.25,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0.0685,
        ],
      },
    });
  }

  void publishGoalPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    _publish('/goal_pose', {
      'header': {
        'stamp': _rosTimeNow(),
        'frame_id': 'map',
      },
      'pose': {
        'position': {'x': x, 'y': y, 'z': 0.0},
        'orientation': _yawQuaternion(yaw),
      },
    });
  }

  Future<void> cancelNavigationAndStop() async {
    _send({
      'op': 'call_service',
      'id': 'cancel-navigation-${DateTime.now().microsecondsSinceEpoch}',
      'service': '/navigate_to_pose/_action/cancel_goal',
      'type': 'action_msgs/srv/CancelGoal',
      'args': {
        'goal_info': {
          'goal_id': {
            'uuid': List<int>.filled(16, 0),
          },
          'stamp': {'sec': 0, 'nanosec': 0},
        },
      },
    });

    const zero = {
      'linear': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      'angular': {'x': 0.0, 'y': 0.0, 'z': 0.0},
    };
    for (var index = 0; index < 4; index += 1) {
      _publish('/cmd_vel', zero);
      if (index < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _connectionController.close();
    await _messageController.close();
  }

  void _registerRosInterfaces() {
    const subscriptions = <_RosSubscription>[
      _RosSubscription('/map', 'nav_msgs/msg/OccupancyGrid'),
      _RosSubscription(
          '/amcl_pose', 'geometry_msgs/msg/PoseWithCovarianceStamped', 100),
      _RosSubscription('/scan', 'sensor_msgs/msg/LaserScan', 160),
      _RosSubscription('/plan', 'nav_msgs/msg/Path', 100),
      _RosSubscription('/local_plan', 'nav_msgs/msg/Path', 100),
      _RosSubscription(
          '/global_costmap/costmap', 'nav_msgs/msg/OccupancyGrid', 900),
      _RosSubscription(
          '/local_costmap/costmap', 'nav_msgs/msg/OccupancyGrid', 350),
      _RosSubscription('/particlecloud', 'geometry_msgs/msg/PoseArray', 350),
      // Let rosbridge infer this topic because Nav2 deployments use either
      // sensor_msgs/PointCloud or sensor_msgs/PointCloud2 for cost clouds.
      _RosSubscription('/cost_cloud', null, 250),
      _RosSubscription('/tf', 'tf2_msgs/msg/TFMessage', 50),
      _RosSubscription('/tf_static', 'tf2_msgs/msg/TFMessage'),
      _RosSubscription('/goal_pose', 'geometry_msgs/msg/PoseStamped'),
      _RosSubscription(
        '/navigate_to_pose/_action/status',
        'action_msgs/msg/GoalStatusArray',
      ),
      // Foxy exposes this generated action wrapper from a private module.
      // Infer the graph type so rosbridge uses the exact installed interface.
      _RosSubscription(
        '/navigate_to_pose/_action/feedback',
        null,
        200,
      ),
      _RosSubscription('/cmd_vel', 'geometry_msgs/msg/Twist', 150),
    ];

    for (final subscription in subscriptions) {
      _send({
        'op': 'subscribe',
        'id': 'inspection-map:${subscription.topic}',
        'topic': subscription.topic,
        if (subscription.type != null) 'type': subscription.type,
        'queue_length': 1,
        if (subscription.throttleRate > 0)
          'throttle_rate': subscription.throttleRate,
      });
    }

    const advertisements = <String, String>{
      '/initialpose': 'geometry_msgs/msg/PoseWithCovarianceStamped',
      '/goal_pose': 'geometry_msgs/msg/PoseStamped',
      '/cmd_vel': 'geometry_msgs/msg/Twist',
    };
    for (final entry in advertisements.entries) {
      _send({
        'op': 'advertise',
        'id': 'inspection-map:advertise:${entry.key}',
        'topic': entry.key,
        'type': entry.value,
      });
    }
  }

  void _handleSocketData(Object? rawData) {
    try {
      final payload = rawData is List<int> ? utf8.decode(rawData) : '$rawData';
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['op'] != 'publish') return;
      final topic = '${envelope['topic'] ?? ''}';
      final rawMessage = envelope['msg'];
      if (topic.isEmpty || rawMessage is! Map) return;
      _messageController.add(
        RosbridgeTopicMessage(
          topic: topic,
          message: Map<String, dynamic>.from(rawMessage),
        ),
      );
    } catch (error) {
      _emitConnection(
        RosbridgeConnectionStatus.error,
        message: 'Invalid rosbridge message: $error',
      );
    }
  }

  void _handleSocketClosed(String reason) {
    if (_manualDisconnect || _disposed) return;
    _emitConnection(
      RosbridgeConnectionStatus.reconnecting,
      message: reason,
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _disposed || _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectAttempt += 1;
    final seconds = math.min(8, math.pow(2, _reconnectAttempt - 1).toInt());
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      final url = _url;
      if (url != null && !_manualDisconnect && !_disposed) {
        unawaited(connect(url));
      }
    });
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    _socketSubscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    await channel?.sink.close(ws_status.normalClosure);
  }

  void _publish(String topic, Map<String, dynamic> message) {
    _send({'op': 'publish', 'topic': topic, 'msg': message});
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null || _status != RosbridgeConnectionStatus.connected) {
      return;
    }
    channel.sink.add(jsonEncode(message));
  }

  void _emitConnection(
    RosbridgeConnectionStatus status, {
    String? message,
  }) {
    _status = status;
    if (!_connectionController.isClosed) {
      _connectionController
          .add(RosbridgeConnectionEvent(status, message: message));
    }
  }

  Map<String, int> _rosTimeNow() {
    final microseconds = DateTime.now().toUtc().microsecondsSinceEpoch;
    return {
      'sec': microseconds ~/ Duration.microsecondsPerSecond,
      'nanosec': (microseconds % Duration.microsecondsPerSecond) * 1000,
    };
  }

  Map<String, double> _yawQuaternion(double yaw) {
    return {
      'x': 0.0,
      'y': 0.0,
      'z': math.sin(yaw / 2),
      'w': math.cos(yaw / 2),
    };
  }
}

class _RosSubscription {
  const _RosSubscription(this.topic, this.type, [this.throttleRate = 0]);

  final String topic;
  final String? type;
  final int throttleRate;
}
