import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _maximumGoalDistanceMeters = 0.20;
const _liveConfirmation = 'ROBOT_AREA_CLEAR';
const _emptyBaselineConfirmation = 'FRESH_NAV2_NO_ACTIVE_GOAL';

Future<void> main(List<String> arguments) async {
  late final _ProbeOptions options;
  try {
    options = _ProbeOptions.parse(arguments);
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  stdout.writeln(
    options.live
        ? 'LIVE command probe armed for an explicitly cleared robot area.'
        : 'Offline command probe. Non-loopback WebSocket targets are blocked.',
  );
  stdout.writeln('Connecting to ${options.url}');
  stdout.writeln(
    'Current=(${options.current.x}, ${options.current.y}, '
    '${options.current.yaw}) goal=(${options.goal.x}, ${options.goal.y}, '
    '${options.goal.yaw}) distance=${options.goalDistance.toStringAsFixed(3)} m',
  );

  final socket = await WebSocket.connect(options.url.toString())
      .timeout(const Duration(seconds: 6));
  final session = _ProbeSession(socket);
  Object? primaryError;
  StackTrace? primaryStackTrace;
  Object? cleanupError;
  StackTrace? cleanupStackTrace;

  try {
    await session.registerInterfaces();
    final baseline = await session.waitForBaselineStatus(
      allowEmptyBaseline: options.allowEmptyBaseline,
    );
    final activeGoals = _goalStates(baseline)
        .where((state) => state.isActive)
        .toList(growable: false);
    if (activeGoals.isNotEmpty) {
      throw StateError(
        'Refusing to publish a probe goal while NavigateToPose already has '
        'an active goal (${activeGoals.map((state) => state.label).join(', ')}).',
      );
    }
    session.armGoalTracking(baseline);

    if (options.live) {
      stdout.writeln(
        'Live mode does not publish /initialpose; AMCL initialization must be '
        'completed separately.',
      );
    } else {
      final initialPoseMessage = _initialPoseMessage(options.current);
      _validateInitialPose(initialPoseMessage, options.current);
      session.publish('/initialpose', initialPoseMessage);
    }

    final goalPoseMessage = _goalPoseMessage(options.goal);
    _validateGoalPose(goalPoseMessage, options.goal);
    session.publish('/inspection_map/goal_pose', goalPoseMessage);

    final goalEcho = await session.goalEcho.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'No /inspection_map/goal_pose echo was observed after publishing '
        'the probe goal.',
      ),
    );
    _validateGoalPose(goalEcho, options.goal);

    final actionState = await session.actionState.timeout(
      options.observationTimeout,
      onTimeout: () => throw TimeoutException(
        'No new NavigateToPose action status was observed.',
      ),
    );
    final feedback = await session.feedback.timeout(
      options.observationTimeout,
      onTimeout: () => throw TimeoutException(session.feedbackTimeoutMessage),
    );
    final distanceRemaining = _validateFeedback(feedback);

    stdout.writeln('ROS bridge command probe command path passed');
    if (!options.live) {
      stdout.writeln(
        '/initialpose PoseWithCovarianceStamped frame=map covariance=36',
      );
    }
    stdout.writeln(
      '/inspection_map/goal_pose PoseStamped frame=map echoed by ROS',
    );
    stdout.writeln(
      'NavigateToPose status=${actionState.label} '
      'feedback.distance_remaining=${distanceRemaining.toStringAsFixed(3)}',
    );
  } catch (error, stackTrace) {
    primaryError = error;
    primaryStackTrace = stackTrace;
  } finally {
    try {
      await session.stopNavigation();
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    await session.close();
  }

  if (primaryError != null) {
    if (cleanupError != null) {
      stderr.writeln('Safety cleanup also reported: $cleanupError');
    }
    Error.throwWithStackTrace(primaryError, primaryStackTrace!);
  }
  if (cleanupError != null) {
    Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
  }

  stdout.writeln(
    'Safety cleanup passed: one Empty stop request was published and the '
    'tracked action reached a terminal state.',
  );
}

class _ProbeSession {
  _ProbeSession(this.socket) {
    _subscription = socket.listen(
      _handleSocketData,
      onError: (Object error, StackTrace stackTrace) {
        _completePendingWithError(error, stackTrace);
      },
      cancelOnError: true,
    );
  }

  final WebSocket socket;
  late final StreamSubscription<dynamic> _subscription;
  final _baselineStatus = Completer<Map<String, dynamic>>();
  final _goalEcho = Completer<Map<String, dynamic>>();
  final _actionState = Completer<_GoalState>();
  final _feedback = Completer<Map<String, dynamic>>();
  final _terminalState = Completer<_GoalState>();
  Set<String> _baselineGoalIds = const {};
  String? _trackedGoalId;
  int _feedbackEnvelopeCount = 0;
  int _postGoalFeedbackEnvelopeCount = 0;
  int _malformedFeedbackGoalIdCount = 0;
  final _rejectedFeedbackGoalIds = <String>{};
  final _rosbridgeErrors = <String>[];
  bool _goalTrackingArmed = false;
  bool _probeGoalPublished = false;
  bool _closed = false;

  Future<Map<String, dynamic>> get goalEcho => _goalEcho.future;
  Future<_GoalState> get actionState => _actionState.future;
  Future<Map<String, dynamic>> get feedback => _feedback.future;

  String get feedbackTimeoutMessage {
    final errors = _rosbridgeErrors.isEmpty
        ? ''
        : ' rosbridge errors=${_rosbridgeErrors.join(' | ')}.';
    if (_postGoalFeedbackEnvelopeCount == 0) {
      return 'No NavigateToPose feedback envelope reached the WebSocket '
          'after the probe goal (all-session envelopes='
          '$_feedbackEnvelopeCount).$errors';
    }
    if (_malformedFeedbackGoalIdCount > 0) {
      return 'Received $_postGoalFeedbackEnvelopeCount NavigateToPose '
          'feedback envelope(s), but $_malformedFeedbackGoalIdCount had a '
          'missing or malformed goal_id UUID.$errors';
    }
    return 'Received $_postGoalFeedbackEnvelopeCount NavigateToPose feedback '
        'envelope(s), but their goal IDs did not match the tracked goal '
        '(rejected=${_rejectedFeedbackGoalIds.join(',')}).$errors';
  }

  Future<void> registerInterfaces() async {
    const subscriptions = <String, String?>{
      '/inspection_map/goal_pose': 'geometry_msgs/msg/PoseStamped',
      '/navigate_to_pose/_action/status': 'action_msgs/msg/GoalStatusArray',
      // Foxy exposes a generated action topic type. Let rosbridge use the
      // exact type already registered in the live ROS graph.
      '/navigate_to_pose/_action/feedback': null,
    };
    for (final entry in subscriptions.entries) {
      _send({
        'op': 'subscribe',
        'id': 'command-probe:subscribe:${entry.key}',
        'topic': entry.key,
        if (entry.value != null) 'type': entry.value,
        'queue_length': 1,
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
        'id': 'command-probe:advertise:${entry.key}',
        'topic': entry.key,
        'type': entry.value,
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<Map<String, dynamic>> waitForBaselineStatus({
    required bool allowEmptyBaseline,
  }) async {
    try {
      return await _baselineStatus.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      if (!allowEmptyBaseline) {
        throw TimeoutException(
          'No baseline NavigateToPose status was received; refusing commands. '
          'For a freshly restarted Nav2 action server with no cached status '
          'sample, explicitly pass '
          '--confirm-empty-baseline=$_emptyBaselineConfirmation.',
        );
      }
      stdout.writeln(
        'No cached NavigateToPose status sample was received. Continuing with '
        'an explicitly confirmed empty baseline; the new goal must still '
        'produce status and feedback.',
      );
      return const {'status_list': <Object>[]};
    }
  }

  void armGoalTracking(Map<String, dynamic> baselineStatus) {
    _baselineGoalIds = _goalStates(baselineStatus)
        .map((state) => state.goalId)
        .where((goalId) => goalId.isNotEmpty)
        .toSet();
    _goalTrackingArmed = true;
  }

  void publish(String topic, Map<String, dynamic> message) {
    if (topic != '/inspection_map/goal_pose') {
      _send({'op': 'publish', 'topic': topic, 'msg': message});
      return;
    }
    _probeGoalPublished = true;
    try {
      _send({'op': 'publish', 'topic': topic, 'msg': message});
    } catch (_) {
      _probeGoalPublished = false;
      rethrow;
    }
  }

  Future<void> stopNavigation() async {
    if (_closed ||
        socket.readyState != WebSocket.open ||
        !_probeGoalPublished) {
      return;
    }
    publish('/inspection_map/stop_navigation', const {});

    final trackedGoalId = _trackedGoalId;
    if (trackedGoalId != null && !_terminalState.isCompleted) {
      await _terminalState.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException(
          'The stop topic was published but the tracked action did not reach '
          'a terminal status.',
        ),
      );
    }
  }

  void _handleSocketData(dynamic raw) {
    try {
      final payload = raw is List<int> ? utf8.decode(raw) : '$raw';
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['op'] == 'publish') {
        final topic = '${envelope['topic'] ?? ''}';
        final message = _map(envelope['msg']);
        switch (topic) {
          case '/inspection_map/goal_pose':
            if (_goalTrackingArmed &&
                _probeGoalPublished &&
                !_goalEcho.isCompleted) {
              _goalEcho.complete(message);
            }
          case '/navigate_to_pose/_action/status':
            _handleStatus(message);
          case '/navigate_to_pose/_action/feedback':
            _handleFeedback(message);
        }
      } else if (envelope['op'] == 'status' && envelope['level'] == 'error') {
        _rosbridgeErrors.add('${envelope['msg'] ?? 'unknown error'}');
      }
    } catch (error, stackTrace) {
      _completePendingWithError(error, stackTrace);
    }
  }

  void _handleStatus(Map<String, dynamic> message) {
    if (!_baselineStatus.isCompleted) {
      _baselineStatus.complete(message);
    }
    if (!_goalTrackingArmed || !_probeGoalPublished) return;

    final candidates = _goalStates(message).where(
      (state) =>
          state.goalId.isNotEmpty && !_baselineGoalIds.contains(state.goalId),
    );
    for (final state in candidates) {
      _trackedGoalId ??= state.goalId;
      if (state.goalId != _trackedGoalId) continue;
      if (!_actionState.isCompleted) {
        _actionState.complete(state);
      }
      if (state.isTerminal && !_terminalState.isCompleted) {
        _terminalState.complete(state);
      }
    }
  }

  void _handleFeedback(Map<String, dynamic> message) {
    _feedbackEnvelopeCount += 1;
    if (!_goalTrackingArmed || !_probeGoalPublished || _feedback.isCompleted) {
      return;
    }
    _postGoalFeedbackEnvelopeCount += 1;
    final feedbackGoalId = _goalId(_map(message['goal_id']));
    if (feedbackGoalId.isEmpty) {
      _malformedFeedbackGoalIdCount += 1;
      return;
    }
    if (_trackedGoalId != null && feedbackGoalId != _trackedGoalId) {
      _rejectedFeedbackGoalIds.add(feedbackGoalId);
      return;
    }
    if (_trackedGoalId == null) {
      if (_baselineGoalIds.contains(feedbackGoalId)) {
        _rejectedFeedbackGoalIds.add(feedbackGoalId);
        return;
      }
      _trackedGoalId = feedbackGoalId;
    }
    _feedback.complete(message);
  }

  void _completePendingWithError(Object error, StackTrace stackTrace) {
    for (final completer in <Completer<dynamic>>[
      _baselineStatus,
      _goalEcho,
      _actionState,
      _feedback,
    ]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  void _send(Map<String, dynamic> message) {
    if (_closed || socket.readyState != WebSocket.open) {
      throw StateError('rosbridge WebSocket is not open');
    }
    socket.add(jsonEncode(message));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await socket.close(WebSocketStatus.normalClosure);
  }
}

class _ProbeOptions {
  const _ProbeOptions({
    required this.url,
    required this.live,
    required this.current,
    required this.goal,
    required this.observationTimeout,
    required this.allowEmptyBaseline,
    this.showHelp = false,
  });

  final Uri url;
  final bool live;
  final _Pose current;
  final _Pose goal;
  final Duration observationTimeout;
  final bool allowEmptyBaseline;
  final bool showHelp;

  double get goalDistance => math.sqrt(
        math.pow(goal.x - current.x, 2) + math.pow(goal.y - current.y, 2),
      );

  factory _ProbeOptions.parse(List<String> arguments) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      return _ProbeOptions(
        url: Uri.parse('ws://127.0.0.1:9090'),
        live: false,
        current: const _Pose(1.25, -2.5, math.pi / 2),
        goal: const _Pose(1.37, -2.5, math.pi / 2),
        observationTimeout: const Duration(seconds: 6),
        allowEmptyBaseline: false,
        showHelp: true,
      );
    }

    final values = <String, String>{};
    final flags = <String>{};
    String? positionalUrl;
    for (final argument in arguments) {
      if (argument.startsWith('--')) {
        final separator = argument.indexOf('=');
        if (separator < 0) {
          flags.add(argument.substring(2));
        } else {
          values[argument.substring(2, separator)] =
              argument.substring(separator + 1);
        }
      } else if (positionalUrl == null) {
        positionalUrl = argument;
      } else {
        throw _UsageException('Unexpected positional argument: $argument');
      }
    }

    const knownFlags = {'live', 'offline'};
    const knownValues = {
      'url',
      'host',
      'port',
      'confirm-live',
      'confirm-empty-baseline',
      'current-x',
      'current-y',
      'current-yaw',
      'goal-x',
      'goal-y',
      'goal-yaw',
      'observe-seconds',
    };
    final unknownFlags = flags.difference(knownFlags);
    final unknownValues = values.keys.toSet().difference(knownValues);
    if (unknownFlags.isNotEmpty || unknownValues.isNotEmpty) {
      throw _UsageException(
        'Unknown option(s): '
        '${[
          ...unknownFlags,
          ...unknownValues
        ].map((value) => '--$value').join(', ')}',
      );
    }
    if (flags.contains('live') && flags.contains('offline')) {
      throw const _UsageException(
          'Choose either --live or --offline, not both.');
    }
    if (positionalUrl != null && values.containsKey('url')) {
      throw const _UsageException(
        'Use either the positional WebSocket URL or --url, not both.',
      );
    }

    final port = _integer(values['port'] ?? '9090', '--port');
    if (port < 1 || port > 65535) {
      throw const _UsageException('--port must be between 1 and 65535.');
    }
    final urlText = values['url'] ??
        positionalUrl ??
        'ws://${values['host'] ?? '127.0.0.1'}:$port';
    final url = Uri.tryParse(urlText);
    if (url == null ||
        (url.scheme != 'ws' && url.scheme != 'wss') ||
        url.host.isEmpty) {
      throw _UsageException('Invalid rosbridge WebSocket URL: $urlText');
    }

    final live = flags.contains('live');
    final loopback = const {'127.0.0.1', 'localhost', '::1'}.contains(url.host);
    if (!live && !loopback) {
      throw _UsageException(
        'Refusing non-loopback target ${url.host} by default. Live use requires '
        '--live --confirm-live=$_liveConfirmation and explicit poses.',
      );
    }
    if (live && values['confirm-live'] != _liveConfirmation) {
      throw const _UsageException(
        'Live mode requires --confirm-live=$_liveConfirmation.',
      );
    }
    final emptyBaselineValue = values['confirm-empty-baseline'];
    if (emptyBaselineValue != null &&
        emptyBaselineValue != _emptyBaselineConfirmation) {
      throw const _UsageException(
        'Empty-baseline override requires '
        '--confirm-empty-baseline=$_emptyBaselineConfirmation.',
      );
    }

    const poseKeys = {
      'current-x',
      'current-y',
      'current-yaw',
      'goal-x',
      'goal-y',
      'goal-yaw',
    };
    if (live) {
      final missing = poseKeys.difference(values.keys.toSet());
      if (missing.isNotEmpty) {
        throw _UsageException(
          'Live mode requires explicit pose option(s): '
          '${missing.map((key) => '--$key').join(', ')}',
        );
      }
    }

    final current = _Pose(
      _number(values['current-x'] ?? '1.25', '--current-x'),
      _number(values['current-y'] ?? '-2.5', '--current-y'),
      _number(values['current-yaw'] ?? '${math.pi / 2}', '--current-yaw'),
    );
    final goal = _Pose(
      _number(values['goal-x'] ?? '1.37', '--goal-x'),
      _number(values['goal-y'] ?? '-2.5', '--goal-y'),
      _number(values['goal-yaw'] ?? '${math.pi / 2}', '--goal-yaw'),
    );
    final observeSeconds =
        _integer(values['observe-seconds'] ?? '6', '--observe-seconds');
    if (observeSeconds < 1 || observeSeconds > 30) {
      throw const _UsageException(
        '--observe-seconds must be between 1 and 30.',
      );
    }

    final result = _ProbeOptions(
      url: url,
      live: live,
      current: current,
      goal: goal,
      observationTimeout: Duration(seconds: observeSeconds),
      allowEmptyBaseline: emptyBaselineValue == _emptyBaselineConfirmation,
    );
    if (result.goalDistance > _maximumGoalDistanceMeters + 1e-9) {
      throw _UsageException(
        'Goal distance ${result.goalDistance.toStringAsFixed(3)} m exceeds the '
        'hard safety limit of $_maximumGoalDistanceMeters m.',
      );
    }
    return result;
  }
}

class _Pose {
  const _Pose(this.x, this.y, this.yaw);

  final double x;
  final double y;
  final double yaw;
}

class _GoalState {
  const _GoalState(this.goalId, this.status);

  final String goalId;
  final int status;

  bool get isActive => status == 1 || status == 2 || status == 3;
  bool get isTerminal => status == 4 || status == 5 || status == 6;

  String get label => switch (status) {
        0 => 'unknown',
        1 => 'accepted',
        2 => 'executing',
        3 => 'canceling',
        4 => 'succeeded',
        5 => 'canceled',
        6 => 'aborted',
        _ => 'status-$status',
      };
}

class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}

Map<String, dynamic> _initialPoseMessage(_Pose pose) {
  final covariance = List<num>.filled(36, 0)
    ..[0] = 0.25
    ..[7] = 0.25
    ..[35] = 0.0685;
  return {
    'header': {'stamp': _rosTimeNow(), 'frame_id': 'map'},
    'pose': {
      'pose': {
        'position': {'x': pose.x, 'y': pose.y, 'z': 0.0},
        'orientation': _yawQuaternion(pose.yaw),
      },
      'covariance': covariance,
    },
  };
}

Map<String, dynamic> _goalPoseMessage(_Pose pose) {
  return {
    'header': {'stamp': _rosTimeNow(), 'frame_id': 'map'},
    'pose': {
      'position': {'x': pose.x, 'y': pose.y, 'z': 0.0},
      'orientation': _yawQuaternion(pose.yaw),
    },
  };
}

void _validateInitialPose(Map<String, dynamic> message, _Pose expected) {
  _validateHeader(message);
  final poseWithCovariance = _map(message['pose']);
  _validatePose(_map(poseWithCovariance['pose']), expected);
  final covariance = poseWithCovariance['covariance'];
  if (covariance is! List || covariance.length != 36) {
    throw StateError('/initialpose covariance must contain 36 values');
  }
  _expectClose(covariance[0], 0.25, 'covariance[0]');
  _expectClose(covariance[7], 0.25, 'covariance[7]');
  _expectClose(covariance[35], 0.0685, 'covariance[35]');
}

void _validateGoalPose(Map<String, dynamic> message, _Pose expected) {
  _validateHeader(message);
  _validatePose(_map(message['pose']), expected);
}

void _validatePose(Map<String, dynamic> pose, _Pose expected) {
  final position = _map(pose['position']);
  _expectClose(position['x'], expected.x, 'position.x');
  _expectClose(position['y'], expected.y, 'position.y');
  _expectClose(position['z'], 0, 'position.z');
  final orientation = _map(pose['orientation']);
  final quaternion = _yawQuaternion(expected.yaw);
  for (final key in const ['x', 'y', 'z', 'w']) {
    _expectClose(orientation[key], quaternion[key]!, 'orientation.$key');
  }
}

void _validateHeader(Map<String, dynamic> message) {
  final header = _map(message['header']);
  if (header['frame_id'] != 'map') {
    throw StateError('Expected frame_id=map, got ${header['frame_id']}');
  }
  final stamp = _map(header['stamp']);
  if (stamp['sec'] is! num || stamp['nanosec'] is! num) {
    throw StateError('ROS header stamp is missing or malformed');
  }
}

double _validateFeedback(Map<String, dynamic> message) {
  final feedback = _map(message['feedback']);
  final distanceRemaining = feedback['distance_remaining'];
  if (distanceRemaining is! num ||
      !distanceRemaining.isFinite ||
      distanceRemaining < 0) {
    throw StateError(
      'NavigateToPose feedback.distance_remaining is malformed: '
      '$distanceRemaining',
    );
  }
  final currentPose = _map(feedback['current_pose']);
  if (currentPose.isNotEmpty) {
    _validateHeader(currentPose);
  }
  return distanceRemaining.toDouble();
}

List<_GoalState> _goalStates(Map<String, dynamic> message) {
  final statusList = message['status_list'];
  if (statusList is! List) return const [];
  return statusList.map((entry) {
    final status = _map(entry);
    final goalInfo = _map(status['goal_info']);
    return _GoalState(
      _goalId(_map(goalInfo['goal_id'])),
      status['status'] is num ? (status['status'] as num).toInt() : 0,
    );
  }).toList(growable: false);
}

String _goalId(Map<String, dynamic> goalId) {
  final uuid = goalId['uuid'];
  List<int> bytes;
  if (uuid is List) {
    if (uuid.length != 16) return '';
    bytes = <int>[];
    for (final value in uuid) {
      if (value is! num ||
          !value.toDouble().isFinite ||
          value.toInt().toDouble() != value.toDouble() ||
          value < 0 ||
          value > 255) {
        return '';
      }
      bytes.add(value.toInt());
    }
  } else if (uuid is String) {
    try {
      bytes = base64.decode(uuid);
    } on FormatException {
      return '';
    }
    if (bytes.length != 16) return '';
  } else {
    return '';
  }
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

void _expectClose(Object? actual, num expected, String label) {
  if (actual is! num || (actual.toDouble() - expected).abs() > 1e-9) {
    throw StateError('$label expected $expected, got $actual');
  }
}

double _number(String value, String option) {
  final parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite) {
    throw _UsageException('$option must be a finite number, got $value.');
  }
  return parsed;
}

int _integer(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    throw _UsageException('$option must be an integer, got $value.');
  }
  return parsed;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
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

const _usage = '''
Usage:
  dart tool/rosbridge_command_probe.dart [ws://127.0.0.1:9090]
  dart tool/rosbridge_command_probe.dart --host=127.0.0.1 --port=9090

Offline pose overrides (radians):
  --current-x=1.25 --current-y=-2.5 --current-yaw=1.5708
  --goal-x=1.37 --goal-y=-2.5 --goal-yaw=1.5708

Live mode requires every safety option below:
  --live --confirm-live=ROBOT_AREA_CLEAR
  --host=<robot-ip> --port=9090
  --current-x=<map-x> --current-y=<map-y> --current-yaw=<radians>
  --goal-x=<map-x> --goal-y=<map-y> --goal-yaw=<radians>

Live mode never publishes /initialpose. Establish AMCL pose separately before
running this goal probe. Offline mode still publishes /initialpose for its
message-structure regression.

Only when Nav2 was freshly restarted and has never produced an action status:
  --confirm-empty-baseline=FRESH_NAV2_NO_ACTIVE_GOAL
Without this exact token, a missing baseline status still refuses all commands.
Received active goals are always rejected, even when this token is present.

The goal must be no more than 0.20 m from the supplied current pose.
Use --observe-seconds=<1..30> to change the status/feedback timeout.
''';
