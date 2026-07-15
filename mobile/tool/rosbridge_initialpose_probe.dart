import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart tool/rosbridge_initialpose_probe.dart '
      '<ws-url> <x> <y> <yaw-radians>',
    );
    exitCode = 64;
    return;
  }

  final url = Uri.parse(arguments[0]);
  final x = double.parse(arguments[1]);
  final y = double.parse(arguments[2]);
  final yaw = double.parse(arguments[3]);
  final socket = await WebSocket.connect(url.toString()).timeout(
    const Duration(seconds: 6),
  );
  final echo = Completer<Map<String, dynamic>>();
  late final StreamSubscription<dynamic> subscription;
  subscription = socket.listen((rawData) {
    final text = rawData is List<int> ? utf8.decode(rawData) : '$rawData';
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['op'] != 'publish') return;
    if ('${decoded['topic'] ?? ''}' != '/initialpose') return;
    final message = decoded['msg'];
    if (message is Map && !echo.isCompleted) {
      echo.complete(Map<String, dynamic>.from(message));
    }
  });

  void send(Map<String, dynamic> envelope) {
    socket.add(jsonEncode(envelope));
  }

  send({
    'op': 'subscribe',
    'id': 'initialpose-probe:subscribe',
    'topic': '/initialpose',
    'type': 'geometry_msgs/msg/PoseWithCovarianceStamped',
    'queue_length': 1,
  });
  send({
    'op': 'advertise',
    'id': 'initialpose-probe:advertise',
    'topic': '/initialpose',
    'type': 'geometry_msgs/msg/PoseWithCovarianceStamped',
  });
  await Future<void>.delayed(const Duration(milliseconds: 500));

  final halfYaw = yaw / 2.0;
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final message = <String, dynamic>{
    'header': {
      'stamp': {
        'sec': now ~/ Duration.microsecondsPerSecond,
        'nanosec': (now % Duration.microsecondsPerSecond) * 1000,
      },
      'frame_id': 'map',
    },
    'pose': {
      'pose': {
        'position': {'x': x, 'y': y, 'z': 0.0},
        'orientation': {
          'x': 0.0,
          'y': 0.0,
          'z': math.sin(halfYaw),
          'w': math.cos(halfYaw),
        },
      },
      'covariance': [
        0.25,
        ...List<double>.filled(6, 0.0),
        0.25,
        ...List<double>.filled(27, 0.0),
        0.0685,
      ],
    },
  };
  final covariance = message['pose'] as Map<String, dynamic>;
  final covarianceValues = covariance['covariance'] as List<dynamic>;
  if (covarianceValues.length != 36) {
    throw StateError('Initial pose covariance must contain 36 values.');
  }

  send({'op': 'publish', 'topic': '/initialpose', 'msg': message});
  final echoed = await echo.future.timeout(
    const Duration(seconds: 6),
    onTimeout: () => throw TimeoutException(
      'No /initialpose ROS echo was observed after publishing.',
    ),
  );
  final echoedPose = Map<String, dynamic>.from(echoed['pose'] as Map);
  final echoedCovariance = echoedPose['covariance'] as List<dynamic>;
  stdout.writeln('Initial pose rosbridge probe passed');
  stdout.writeln(
    'frame=${(echoed['header'] as Map)['frame_id']} '
    'x=$x y=$y yaw=$yaw covariance=${echoedCovariance.length}',
  );

  send({'op': 'unadvertise', 'topic': '/initialpose'});
  await subscription.cancel();
  await socket.close(WebSocketStatus.normalClosure);
}
