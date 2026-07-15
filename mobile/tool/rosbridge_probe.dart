import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final url =
      arguments.isEmpty ? 'ws://192.168.160.125:9090' : arguments.first.trim();
  stdout.writeln('Connecting to $url');

  final socket =
      await WebSocket.connect(url).timeout(const Duration(seconds: 6));
  final received = <String, int>{};
  final details = <String, String>{};
  final done = Completer<void>();

  final subscription = socket.listen(
    (raw) {
      final payload = raw is List<int> ? utf8.decode(raw) : '$raw';
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      if (decoded['op'] != 'publish') {
        stdout.writeln(
          'rosbridge op=${decoded['op']} '
          'level=${decoded['level'] ?? ''} '
          'msg=${decoded['msg'] ?? ''}',
        );
        return;
      }
      final topic = '${decoded['topic'] ?? ''}';
      final message = decoded['msg'];
      received.update(topic, (count) => count + 1, ifAbsent: () => 1);

      if (message is Map) {
        if (topic == '/map') {
          final info = _map(message['info']);
          final data = message['data'];
          details[topic] = '${info['width']}x${info['height']} '
              'resolution=${info['resolution']} '
              'cells=${data is List ? data.length : 0}';
        } else if (topic == '/scan') {
          final ranges = message['ranges'];
          details[topic] = 'ranges=${ranges is List ? ranges.length : 0}';
        } else if (topic == '/amcl_pose') {
          final pose = _map(_map(message['pose'])['pose']);
          final position = _map(pose['position']);
          details[topic] = 'x=${position['x']} y=${position['y']}';
        } else if (topic == '/plan') {
          final poses = message['poses'];
          details[topic] = 'poses=${poses is List ? poses.length : 0}';
        }
      }

      if (received.containsKey('/map') && received.containsKey('/scan')) {
        if (!done.isCompleted) done.complete();
      }
    },
    onError: done.completeError,
    onDone: () {
      if (!done.isCompleted) {
        done.completeError(
            StateError('WebSocket closed before map and scan arrived'));
      }
    },
  );

  const topics = <String, String>{
    '/map': 'nav_msgs/msg/OccupancyGrid',
    '/scan': 'sensor_msgs/msg/LaserScan',
    '/amcl_pose': 'geometry_msgs/msg/PoseWithCovarianceStamped',
    '/plan': 'nav_msgs/msg/Path',
  };
  for (final entry in topics.entries) {
    socket.add(jsonEncode({
      'op': 'subscribe',
      'id': 'probe:${entry.key}',
      'topic': entry.key,
      'type': entry.value,
      'queue_length': 1,
      if (entry.key == '/scan') 'throttle_rate': 250,
    }));
  }

  Object? failure;
  try {
    await done.future.timeout(const Duration(seconds: 12));
  } catch (error) {
    failure = error;
  } finally {
    await subscription.cancel();
    await socket.close(WebSocketStatus.normalClosure);
  }

  stdout.writeln(
    failure == null ? 'ROS bridge probe passed' : 'ROS bridge probe incomplete',
  );
  for (final topic in topics.keys) {
    stdout.writeln(
      '$topic messages=${received[topic] ?? 0} ${details[topic] ?? ''}'.trim(),
    );
  }
  if (failure != null) {
    throw failure;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
