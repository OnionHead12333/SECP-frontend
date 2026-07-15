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
  RosbridgeNavigationClient({
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _channelFactory =
            channelFactory ?? ((uri) => WebSocketChannel.connect(uri));

  final _connectionController =
      StreamController<RosbridgeConnectionEvent>.broadcast();
  final _messageController =
      StreamController<RosbridgeTopicMessage>.broadcast();

  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _socketSubscription;
  Timer? _reconnectTimer;
  String? _url;
  bool _manualDisconnect = true;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  int _connectionGeneration = 0;
  RosbridgeConnectionStatus _status = RosbridgeConnectionStatus.disconnected;

  Stream<RosbridgeConnectionEvent> get connectionEvents =>
      _connectionController.stream;

  Stream<RosbridgeTopicMessage> get messages => _messageController.stream;

  RosbridgeConnectionStatus get status => _status;

  Future<void> connect(String url) async {
    if (_disposed) {
      throw StateError('ROS bridge client has been disposed');
    }
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('ROS bridge URL is empty');
    }

    final generation = ++_connectionGeneration;
    _manualDisconnect = false;
    _url = trimmedUrl;
    _reconnectTimer?.cancel();
    await _closeSocket();
    if (!_isActiveGeneration(generation)) return;
    _emitConnection(
      _reconnectAttempt == 0
          ? RosbridgeConnectionStatus.connecting
          : RosbridgeConnectionStatus.reconnecting,
    );

    WebSocketChannel? channel;
    try {
      channel = _channelFactory(Uri.parse(trimmedUrl));
      if (!_isActiveGeneration(generation)) {
        await _discardChannel(channel);
        return;
      }
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 6));
      if (!_isCurrentChannel(generation, channel)) {
        await _discardChannel(channel);
        return;
      }

      _reconnectAttempt = 0;
      _emitConnection(RosbridgeConnectionStatus.connected);
      _socketSubscription = channel.stream.listen(
        _handleSocketData,
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketClosed(
            'WebSocket error: $error',
            generation,
            channel!,
          );
        },
        onDone: () {
          _handleSocketClosed('WebSocket closed', generation, channel!);
        },
        cancelOnError: true,
      );
      _registerRosInterfaces();
    } catch (error) {
      await _discardChannel(channel);
      if (!_isActiveGeneration(generation)) return;
      _emitConnection(
        RosbridgeConnectionStatus.error,
        message: '$error',
      );
      _scheduleReconnect(generation);
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _connectionGeneration += 1;
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
    _publish('/inspection_map/goal_pose', {
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

  void stopNavigation() {
    _publish('/inspection_map/stop_navigation', const {});
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
      _RosSubscription(
        '/inspection_map/goal_pose',
        'geometry_msgs/msg/PoseStamped',
      ),
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
      '/inspection_map/goal_pose': 'geometry_msgs/msg/PoseStamped',
      '/inspection_map/stop_navigation': 'std_msgs/msg/Empty',
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

  void _handleSocketClosed(
    String reason,
    int generation,
    WebSocketChannel channel,
  ) {
    if (!_isCurrentChannel(generation, channel)) return;
    _emitConnection(
      RosbridgeConnectionStatus.reconnecting,
      message: reason,
    );
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (_manualDisconnect || _disposed || _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectAttempt += 1;
    final seconds = math.min(8, math.pow(2, _reconnectAttempt - 1).toInt());
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      final url = _url;
      if (url != null && _isActiveGeneration(generation)) {
        unawaited(connect(url));
      }
    });
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    _socketSubscription = null;
    final channel = _channel;
    _channel = null;
    await subscription?.cancel();
    await _closeChannel(channel);
  }

  Future<void> _discardChannel(WebSocketChannel? channel) async {
    if (channel == null) return;
    StreamSubscription<Object?>? subscription;
    if (identical(_channel, channel)) {
      _channel = null;
      subscription = _socketSubscription;
      _socketSubscription = null;
    }
    await subscription?.cancel();
    await _closeChannel(channel);
  }

  Future<void> _closeChannel(WebSocketChannel? channel) async {
    if (channel == null) return;
    try {
      await channel.sink.close(ws_status.normalClosure);
    } catch (_) {
      // The channel can already be closed after a failed handshake.
    }
  }

  bool _isActiveGeneration(int generation) {
    return generation == _connectionGeneration &&
        !_manualDisconnect &&
        !_disposed;
  }

  bool _isCurrentChannel(int generation, WebSocketChannel channel) {
    return _isActiveGeneration(generation) && identical(_channel, channel);
  }

  void _publish(String topic, Map<String, dynamic> message) {
    _send({'op': 'publish', 'topic': topic, 'msg': message});
  }

  bool _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null || _status != RosbridgeConnectionStatus.connected) {
      return false;
    }
    try {
      channel.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      return false;
    }
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
