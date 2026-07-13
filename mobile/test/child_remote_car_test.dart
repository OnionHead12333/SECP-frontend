import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/car_encoder.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/car_tcp_client.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/child_remote_car_gateway_client.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/remote_car_models.dart';
import 'package:smart_elderly_care_mobile/features/child/presentation/pages/child_remote_car_page.dart';

void main() {
  test('car encoder emits smart car button protocol', () {
    expect(CarEncoder.button(CarDirection.front), r'$011504011B#');
    expect(CarEncoder.button(CarDirection.brake), r'$0115040721#');
  });

  test('remote car commands map to TCP directions', () {
    expect(RemoteCarCommand.forward.tcpDirection, CarDirection.front);
    expect(RemoteCarCommand.backward.tcpDirection, CarDirection.back);
    expect(RemoteCarCommand.left.tcpDirection, CarDirection.leftRotate);
    expect(RemoteCarCommand.right.tcpDirection, CarDirection.rightRotate);
    expect(RemoteCarCommand.stop.tcpDirection, CarDirection.stop);
    expect(RemoteCarCommand.emergencyStop.tcpDirection, CarDirection.brake);
    expect(RemoteCarCommand.resetEmergency.tcpDirection, isNull);
  });

  test('ros car state parses gateway fields', () {
    final state = RosCarState.fromJson({
      'current_cmd': 'forward',
      'fall_alert': true,
      'risk_level': 'high',
      'obstacle_status': 'front_blocked',
      'navigation_status': 'manual',
      'control_connected': true,
      'emergency_stop': false,
      'control_block_reason': 'clear',
    });

    expect(state.currentCmd, 'forward');
    expect(state.fallAlert, isTrue);
    expect(state.riskLevel, 'high');
    expect(state.obstacleStatus, 'front_blocked');
    expect(state.navigationStatus, 'manual');
    expect(state.controlConnected, isTrue);
    expect(state.emergencyStop, isFalse);
    expect(state.controlBlockReason, 'clear');
  });

  test('gateway client posts command and gets state from gateway base url',
      () async {
    final calls = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add('${options.method} ${options.uri}');
            if (options.path.endsWith('/api/state')) {
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  data: {
                    'current_cmd': 'stop',
                    'fall_alert': false,
                    'risk_level': 'low',
                    'obstacle_status': 'clear',
                    'navigation_status': 'idle',
                    'control_connected': true,
                    'emergency_stop': false,
                    'control_block_reason': '',
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                data: {'ok': true},
              ),
            );
          },
        ),
      );
    final client = ChildRemoteCarGatewayClient(dio: dio);

    await client.sendCommand(
      gatewayBaseUrl: 'http://192.168.1.10:9090',
      command: RemoteCarCommand.forward,
    );
    final state = await client.fetchState(
      gatewayBaseUrl: 'http://192.168.1.10:9090',
    );

    expect(calls, [
      'POST http://192.168.1.10:9090/api/command',
      'GET http://192.168.1.10:9090/api/state',
    ]);
    expect(state.currentCmd, 'stop');
  });

  testWidgets('remote car page switches modes and disables TCP reset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          gatewayClient: _FakeGatewayClient(),
          tcpClient: _FakeTcpClient(),
        ),
      ),
    );

    await tester.tap(find.text('TCP直连'));
    await tester.pumpAndSettle();

    final resetButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '解除急停'));
    expect(resetButton.onPressed, isNull);
  });

  testWidgets('remote car page renders ROS2 state after refresh',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          gatewayClient: _FakeGatewayClient(),
          tcpClient: _FakeTcpClient(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('gatewayBaseUrlField')),
      'http://gateway.local:9090',
    );
    await tester.tap(find.text('刷新状态'));
    await tester.pumpAndSettle();

    expect(find.text('current_cmd'), findsOneWidget);
    expect(find.text('forward'), findsWidgets);
    expect(find.text('risk_level'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
  });

  testWidgets('tcp host field accepts dotted IP input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          gatewayClient: _FakeGatewayClient(),
          tcpClient: _FakeTcpClient(),
        ),
      ),
    );

    await tester.tap(find.text('TCP直连'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.widgetWithText(TextField, '小车 IP'),
    );
    expect(textField.keyboardType, TextInputType.url);
  });
}

class _FakeGatewayClient extends ChildRemoteCarGatewayClient {
  @override
  Future<void> sendCommand({
    required String gatewayBaseUrl,
    required RemoteCarCommand command,
  }) async {}

  @override
  Future<RosCarState> fetchState({required String gatewayBaseUrl}) async {
    return RosCarState.fromJson({
      'current_cmd': 'forward',
      'fall_alert': false,
      'risk_level': 'high',
      'obstacle_status': 'clear',
      'navigation_status': 'manual',
      'control_connected': true,
      'emergency_stop': false,
      'control_block_reason': '',
    });
  }
}

class _FakeTcpClient extends CarTcpClient {
  bool connected = false;
  final sent = <String>[];

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect(String host, int port) async {
    connected = true;
  }

  @override
  Future<void> send(String message) async {
    sent.add(message);
  }

  @override
  Future<void> close() async {
    connected = false;
  }
}
