import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/data/rosbridge_navigation_client.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map_2/presentation/inspection_map_2_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('captures AMCL home and returns automatically after cooldown',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = _Map2RosbridgeChannel();
    final client = RosbridgeNavigationClient(channelFactory: (_) => channel);
    addTearDown(client.dispose);
    addTearDown(channel.closeIncoming);

    await tester.pumpWidget(
      MaterialApp(
        home: InspectionMap2Page(
          initialUrl: 'ws://test:9090',
          autoConnect: false,
          rosClient: client,
        ),
      ),
    );
    await client.connect('ws://test:9090');
    await tester.pump();
    expect(find.text('connected'), findsOneWidget);

    channel.publish('/amcl_pose', _amclPoseMessage());
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('map2-capture-home')));
    await tester.tap(find.byKey(const ValueKey('map2-capture-home')));
    await tester.pump();
    expect(find.text('Home captured'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map2-target-mode-label')));
    await tester.pump();
    final map = find.byKey(const ValueKey('map2-map-surface'));
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    expect(find.text('Target ready'), findsOneWidget);

    final goButton = find.byKey(const ValueKey('map2-go'));
    await tester.ensureVisible(goButton);
    await tester.tap(goButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Go'));
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
    await tester.pump();
    expect(find.text('Waiting to return automatically'), findsOneWidget);
    expect(find.byKey(const ValueKey('map2-return')), findsNothing);
    expect(channel.published('/inspection_map/goal_pose'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1999));
    expect(channel.published('/inspection_map/goal_pose'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Sending automatic return'), findsOneWidget);

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

class _Map2RosbridgeChannel implements WebSocketChannel {
  final _incoming = StreamController<Object?>.broadcast();
  final _sink = _Map2WebSocketSink();

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

class _Map2WebSocketSink implements WebSocketSink {
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
