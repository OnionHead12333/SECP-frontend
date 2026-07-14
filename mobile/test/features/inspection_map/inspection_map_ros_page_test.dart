import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/app/smart_elderly_care_app.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/employee_robot_inspection_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/data/rosbridge_navigation_client.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/presentation/inspection_map_ros_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('formal app registers the ROS map route without replacing legacy',
      (tester) async {
    await tester.pumpWidget(const SmartElderlyCareApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.routes?['/inspection/map'], isNotNull);
    final employeeMapBuilder =
        materialApp.routes?['/employee/robot-inspection'];
    expect(employeeMapBuilder, isNotNull);
    expect(
      employeeMapBuilder!(tester.element(find.byType(MaterialApp))),
      isA<EmployeeRobotInspectionPage>(),
    );
    final rosMapBuilder = materialApp.routes?['/inspection-map'];
    expect(rosMapBuilder, isNotNull);

    final routeWidget =
        rosMapBuilder!(tester.element(find.byType(MaterialApp)));
    expect(routeWidget, isA<InspectionMapRosPage>());
  });

  testWidgets('shows new offline map metadata and blocks blind navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: InspectionMapRosPage(autoConnect: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('864 x 896 / 0.050 m/cell'),
      findsNWidgets(2),
    );
    expect(
      find.textContaining('Navigate disabled: rosbridge 未连接'),
      findsOneWidget,
    );

    final navigateButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Navigate'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(navigateButton.onPressed, isNull);
  });

  testWidgets('employee mode exposes map navigation and safe startup sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: InspectionMapRosPage(
          autoConnect: false,
          experience: InspectionMapExperience.employee,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('巡检机器人'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('inspection-map-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('employee-inspection-map-tab')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('employee-inspection-navigation-tab')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('employee-inspection-startup-tab')),
        findsOneWidget);
    expect(find.text('ROS WebSocket'), findsNothing);
    expect(find.textContaining('18080'), findsNothing);
    expect(find.textContaining('n1'), findsNothing);
    expect(find.textContaining('n3'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('employee-inspection-navigation-tab')),
    );
    await tester.pumpAndSettle();
    expect(find.text('导航准备'), findsOneWidget);
    expect(find.text('开始导航'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('停止导航'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('employee-inspection-startup-tab')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('employee-inspection-startup-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('employee-inspection-startup-unconfigured')),
      findsOneWidget,
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('employee-inspection-start-services')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('guards duplicate Navigate and Stop rosbridge commands',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = _WidgetRosbridgeChannel();
    addTearDown(channel.closeIncoming);
    final client = RosbridgeNavigationClient(channelFactory: (_) => channel);
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: InspectionMapRosPage(
          initialUrl: 'ws://test:9090',
          autoConnect: false,
          rosClient: client,
        ),
      ),
    );
    await client.connect('ws://test:9090');
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
    expect(
      channel.messages.any(
        (message) =>
            message['op'] == 'advertise' &&
            message['topic'] == '/inspection_map/stop_navigation',
      ),
      isTrue,
    );

    final stopButton = find.byKey(
      const ValueKey('inspection-map-stop'),
      skipOffstage: false,
    );
    final stopAction = tester.widget<FilledButton>(stopButton).onPressed;
    expect(stopAction, isNotNull);
    stopAction!();
    await tester.pump();
    expect(find.text('Stopping...', skipOffstage: false), findsOneWidget);
    expect(tester.widget<FilledButton>(stopButton).onPressed, isNull);
    stopAction();
    await tester.pump();

    final stopMessages = channel.published('/inspection_map/stop_navigation');
    expect(stopMessages, hasLength(1));
    expect(stopMessages.single['msg'], isEmpty);
    expect(
      channel.messages.where((message) => message['op'] == 'call_service'),
      isEmpty,
    );
    expect(channel.published('/cmd_vel'), isEmpty);

    await tester.pump(const Duration(milliseconds: 801));
    expect(tester.widget<FilledButton>(stopButton).onPressed, isNotNull);

    await tester.runAsync(() async {
      channel.publish('/map', _mapMessage());
      channel.publish('/amcl_pose', _amclPoseMessage());
      channel.publish('/scan', _scanMessage());
      channel.publish(
        '/inspection_map/goal_pose',
        _goalPoseSelectionMessage(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    final navigateButton = find.byKey(
      const ValueKey('inspection-map-navigate'),
      skipOffstage: false,
    );
    await _pumpUntil(
      tester,
      () => tester.widget<FilledButton>(navigateButton).onPressed != null,
    );
    final navigateAction =
        tester.widget<FilledButton>(navigateButton).onPressed!;
    navigateAction();
    await tester.pump();
    expect(find.text('Sending...', skipOffstage: false), findsOneWidget);
    expect(tester.widget<FilledButton>(navigateButton).onPressed, isNull);
    navigateAction();
    await tester.pump();

    expect(channel.published('/inspection_map/goal_pose'), hasLength(1));
    expect(
      channel.messages.where((message) => message['op'] == 'call_service'),
      isEmpty,
    );
    expect(channel.published('/cmd_vel'), isEmpty);

    channel.publish('/navigate_to_pose/_action/status', _goalStatusMessage(2));
    await tester.pump(const Duration(milliseconds: 801));
    expect(tester.widget<FilledButton>(navigateButton).onPressed, isNull);

    channel.publish('/navigate_to_pose/_action/status', _goalStatusMessage(4));
    await tester.pump();
    expect(tester.widget<FilledButton>(navigateButton).onPressed, isNotNull);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text, skipOffstage: false))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  throw TimeoutException('Timed out waiting for widget state: $visibleText');
}

Map<String, dynamic> _mapMessage() {
  return {
    'header': {'frame_id': 'map'},
    'info': {
      'width': 2,
      'height': 2,
      'resolution': 0.05,
      'origin': {
        'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
      },
    },
    'data': [0, 0, 0, 0],
  };
}

Map<String, dynamic> _amclPoseMessage() {
  return {
    'header': {'frame_id': 'map'},
    'pose': {
      'pose': {
        'position': {'x': 0.025, 'y': 0.025, 'z': 0.0},
        'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
      },
      'covariance': List<double>.filled(36, 0),
    },
  };
}

Map<String, dynamic> _scanMessage() {
  return {
    'header': {'frame_id': 'map'},
    'angle_min': 0.0,
    'angle_increment': 0.1,
    'range_min': 0.1,
    'range_max': 10.0,
    'ranges': [1.0],
  };
}

Map<String, dynamic> _goalPoseSelectionMessage() {
  return {
    'header': {'frame_id': 'map'},
    'pose': {
      'position': {'x': 0.075, 'y': 0.075, 'z': 0.0},
      'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
    },
  };
}

Map<String, dynamic> _goalStatusMessage(int status) {
  return {
    'status_list': [
      {'status': status},
    ],
  };
}

class _WidgetRosbridgeChannel implements WebSocketChannel {
  final _incoming = StreamController<Object?>.broadcast();
  final _sink = _WidgetWebSocketSink();

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

class _WidgetWebSocketSink implements WebSocketSink {
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
