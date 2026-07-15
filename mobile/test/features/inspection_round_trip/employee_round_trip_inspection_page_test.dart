import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/data/rosbridge_navigation_client.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/data/employee_round_trip_command_gateway.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/models/round_trip_backend_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/presentation/employee_round_trip_inspection_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('安卓页面独立完成自动往返且只使用隔离 topic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = _RoundTripRosbridgeChannel();
    final client = RosbridgeNavigationClient(channelFactory: (_) => channel);
    addTearDown(client.dispose);
    addTearDown(channel.closeIncoming);

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeRoundTripInspectionPage(
          initialUrl: 'ws://test:9090',
          autoConnect: false,
          rosClient: client,
        ),
      ),
    );
    await client.connect('ws://test:9090');
    await tester.pump();
    expect(find.text('机器人已连接'), findsOneWidget);

    final map = find.byKey(const ValueKey('employee-round-trip-map'));
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    final setStart =
        find.byKey(const ValueKey('employee-round-trip-set-start'));
    await tester.ensureVisible(setStart);
    await tester.tap(setStart);
    await tester.pump();
    expect(channel.published('/initialpose'), hasLength(1));

    channel.publish('/amcl_pose', _amclPoseMessage());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('employee-round-trip-target-mode')),
    );
    await tester.pump();
    final capture =
        find.byKey(const ValueKey('employee-round-trip-capture-home'));
    await tester.ensureVisible(capture);
    await tester.tap(capture);
    await tester.pump();
    expect(find.text('返航点已记录'), findsOneWidget);

    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    expect(find.text('目标点已选择'), findsOneWidget);

    final go = find.byKey(const ValueKey('employee-round-trip-go'));
    await tester.ensureVisible(go);
    await tester.tap(go);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pump();
    expect(channel.published('/inspection_map/goal_pose'), hasLength(1));

    channel.publish(
      '/navigate_to_pose/_action/status',
      _goalStatusMessage([1, 2, 3], 2),
    );
    await tester.pump();
    channel.publish(
      '/navigate_to_pose/_action/status',
      _goalStatusMessage([1, 2, 3], 4),
    );
    await tester.pump(const Duration(seconds: 2));

    final goals = channel.published('/inspection_map/goal_pose');
    expect(goals, hasLength(2));
    final returnMessage = _asMap(goals.last['msg']);
    final returnPose = _asMap(returnMessage['pose']);
    final returnPosition = _asMap(returnPose['position']);
    expect(returnPosition['x'], closeTo(1.2, 1e-9));
    expect(returnPosition['y'], closeTo(-0.4, 1e-9));
    expect(channel.published('/goal_pose'), isEmpty);
    expect(channel.published('/cmd_vel'), isEmpty);
  });

  testWidgets('后端模式只调用网关且不会发布任何 ROS 控制命令', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = _RoundTripRosbridgeChannel();
    final client = RosbridgeNavigationClient(channelFactory: (_) => channel);
    final gateway = _BackendWidgetGateway();
    addTearDown(client.dispose);
    addTearDown(channel.closeIncoming);

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeRoundTripInspectionPage(
          initialUrl: 'ws://test:9090',
          autoConnect: false,
          rosClient: client,
          commandGateway: gateway,
          backendPollInterval: const Duration(days: 1),
        ),
      ),
    );
    await client.connect('ws://test:9090');
    await tester.pump();
    expect(find.text('控制：后端受控'), findsOneWidget);
    expect(find.text('ROS 遥测已连接'), findsOneWidget);

    final map = find.byKey(const ValueKey('employee-round-trip-map'));
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    final setStart =
        find.byKey(const ValueKey('employee-round-trip-set-start'));
    await tester.ensureVisible(setStart);
    await tester.tap(setStart);
    await tester.pump();
    expect(gateway.initialPoses, hasLength(1));
    expect(channel.published('/initialpose'), isEmpty);

    channel.publish('/amcl_pose', _amclPoseMessage());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('employee-round-trip-target-mode')),
    );
    await tester.pump();
    final capture =
        find.byKey(const ValueKey('employee-round-trip-capture-home'));
    await tester.ensureVisible(capture);
    await tester.tap(capture);
    await tester.pump();
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();

    final go = find.byKey(const ValueKey('employee-round-trip-go'));
    await tester.ensureVisible(go);
    await tester.tap(go);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pump();
    expect(gateway.outboundTargets, hasLength(1));
    expect(find.text('Task task-widget'), findsOneWidget);

    channel.publish(
      '/navigate_to_pose/_action/status',
      _goalStatusMessage([9, 9, 9], 4),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(gateway.returnTargets, isEmpty);
    expect(channel.published('/inspection_map/goal_pose'), isEmpty);

    await client.disconnect();
    await tester.pump();
    expect(find.text('ROS 遥测未连接'), findsOneWidget);
    final stop = find.byKey(const ValueKey('employee-round-trip-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pump();
    expect(gateway.stopCount, 1);
    expect(gateway.stoppedTaskIds, ['task-widget']);
    expect(channel.published('/inspection_map/stop_navigation'), isEmpty);
    expect(channel.published('/initialpose'), isEmpty);
    expect(channel.published('/inspection_map/goal_pose'), isEmpty);
  });
}

Map<String, dynamic> _amclPoseMessage() {
  return {
    'header': {'frame_id': 'map'},
    'pose': {
      'pose': {
        'position': {'x': 1.2, 'y': -0.4, 'z': 0.0},
        'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
      },
      'covariance': List<double>.filled(36, 0),
    },
  };
}

Map<String, dynamic> _goalStatusMessage(List<int> uuid, int status) {
  return {
    'status_list': [
      {
        'goal_info': {
          'goal_id': {'uuid': uuid},
        },
        'status': status,
      },
    ],
  };
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

class _RoundTripRosbridgeChannel implements WebSocketChannel {
  final _incoming = StreamController<Object?>.broadcast();
  final _sink = _RoundTripWebSocketSink();

  List<Map<String, dynamic>> get messages => _sink.values
      .map((value) => jsonDecode('$value'))
      .whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value))
      .toList(growable: false);

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void publish(String topic, Map<String, dynamic> message) {
    _incoming.add(
      jsonEncode({'op': 'publish', 'topic': topic, 'msg': message}),
    );
  }

  List<Map<String, dynamic>> published(String topic) {
    return messages
        .where(
          (message) => message['op'] == 'publish' && message['topic'] == topic,
        )
        .toList(growable: false);
  }

  Future<void> closeIncoming() async {
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RoundTripWebSocketSink implements WebSocketSink {
  final values = <Object?>[];
  final _done = Completer<void>();
  bool _closed = false;

  @override
  void add(dynamic data) {
    if (_closed) throw StateError('WebSocket sink is closed');
    values.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_closed) throw StateError('WebSocket sink is closed');
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final value in stream) {
      add(value);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (_closed) return;
    _closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

class _BackendWidgetGateway implements EmployeeRoundTripCommandGateway {
  @override
  RoundTripCommandMode get mode => RoundTripCommandMode.backendMediated;

  final initialPoses = <RosPose2D>[];
  final outboundTargets = <RosPose2D>[];
  final returnTargets = <RosPose2D>[];
  final stoppedTaskIds = <String?>[];
  int stopCount = 0;

  @override
  Future<void> setInitialPose(RosPose2D pose) async {
    initialPoses.add(pose);
  }

  @override
  Future<RoundTripStartReceipt> startOutbound({
    required RosPose2D home,
    required RosPose2D target,
  }) async {
    outboundTargets.add(target);
    return const RoundTripStartReceipt(
      task: BackendRoundTripTaskSnapshot(
        taskId: 'task-widget',
        status: 'QUEUED',
      ),
    );
  }

  @override
  Future<void> startReturn(RosPose2D home) async {
    returnTargets.add(home);
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> stop({String? taskId}) async {
    stopCount += 1;
    stoppedTaskIds.add(taskId);
    return BackendRoundTripTaskSnapshot(
      taskId: taskId ?? '',
      status: 'CANCEL_REQUESTED',
    );
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> loadTask(String taskId) async {
    return BackendRoundTripTaskSnapshot(taskId: taskId, status: 'QUEUED');
  }
}
