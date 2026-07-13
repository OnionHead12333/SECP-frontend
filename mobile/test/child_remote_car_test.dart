import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/car_encoder.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/car_tcp_client.dart';
import 'package:smart_elderly_care_mobile/features/child/data/remote_car/remote_car_models.dart';
import 'package:smart_elderly_care_mobile/features/child/presentation/pages/child_remote_car_page.dart';

void main() {
  test('car encoder emits smart car button protocol', () {
    expect(CarEncoder.button(CarDirection.front), r'$011504011B#');
    expect(CarEncoder.button(CarDirection.brake), r'$0115040721#');
  });

  test('car encoder emits smart car rocker and wheel speed protocol', () {
    expect(CarEncoder.rocker(60, -60), r'$0110063CC417#');
    expect(CarEncoder.wheelSpeeds(10, 20, -30, -40), r'$01210A0A14E2D804#');
  });

  test('remote car commands map to TCP directions', () {
    expect(RemoteCarCommand.forward.tcpDirection, CarDirection.front);
    expect(RemoteCarCommand.backward.tcpDirection, CarDirection.back);
    expect(RemoteCarCommand.left.tcpDirection, CarDirection.leftRotate);
    expect(RemoteCarCommand.right.tcpDirection, CarDirection.rightRotate);
    expect(RemoteCarCommand.stop.tcpDirection, CarDirection.stop);
    expect(RemoteCarCommand.emergencyStop.tcpDirection, CarDirection.brake);
  });

  testWidgets('remote car page only exposes TCP direct controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FakeTcpClient(),
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    expect(find.text('ROS2网关'), findsNothing);
    expect(find.text('TCP直连'), findsNothing);
    expect(find.text('解除急停'), findsNothing);
    expect(find.text('连接 TCP'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('紧急停止'), findsOneWidget);
  });

  testWidgets('tcp host field accepts dotted IP input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FakeTcpClient(),
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    final textField = tester.widget<TextField>(
      find.byKey(const Key('carIpField')),
    );
    expect(textField.keyboardType, TextInputType.url);
  });

  testWidgets('remote car page keeps TCP control port fixed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FakeTcpClient(),
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    expect(find.byKey(const Key('carPortField')), findsNothing);
    expect(find.text('控制端口'), findsNothing);
  });

  testWidgets('remote car page uses default car IP for mjpeg video stream',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FakeTcpClient(),
          mjpegBuilder: (_, streamUrl) => Text(
            streamUrl,
            key: const Key('fakeMjpeg'),
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(
      find.byKey(const Key('carIpField')),
    );
    expect(textField.controller?.text, '10.40.70.125');
    expect(find.text('http://10.40.70.125:6500/video_feed'), findsWidgets);
    expect(find.byKey(const Key('openVideoButton')), findsNothing);
    expect(find.byKey(const Key('fakeMjpeg')), findsOneWidget);
  });

  testWidgets('remote car page connects default TCP endpoint', (tester) async {
    final tcpClient = _FakeTcpClient();
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: tcpClient,
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    await tester.tap(find.text('连接 TCP'));
    await tester.pump();

    expect(tcpClient.host, '10.40.70.125');
    expect(tcpClient.port, 6000);
  });

  testWidgets('remote car page updates video stream when car IP changes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FakeTcpClient(),
          mjpegBuilder: (_, streamUrl) => Text(streamUrl),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('carIpField')), '192.168.1.8');
    await tester.pump();

    expect(find.text('http://192.168.1.8:6500/video_feed'), findsWidgets);
  });

  testWidgets('remote car page shows TCP connection failure message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: _FailingTcpClient(),
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    await tester.tap(find.text('连接 TCP'));
    await tester.pump();

    expect(
      find.text('小车控制连接失败，请确认 app.py 已启动，6000 端口可访问'),
      findsOneWidget,
    );
  });

  testWidgets('remote car page exposes speed-limited rocker controls',
      (tester) async {
    final tcpClient = _FakeTcpClient();
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: tcpClient,
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    await tester.tap(find.text('连接 TCP'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rockerXSlider')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    var xSlider = tester.widget<Slider>(find.byKey(const Key('rockerXSlider')));
    var ySlider = tester.widget<Slider>(find.byKey(const Key('rockerYSlider')));
    expect(xSlider.max, 60);
    expect(ySlider.max, 60);
    expect(find.text('中速 60'), findsOneWidget);

    await tester.tap(find.text('快速'));
    await tester.pump();

    xSlider = tester.widget<Slider>(find.byKey(const Key('rockerXSlider')));
    ySlider = tester.widget<Slider>(find.byKey(const Key('rockerYSlider')));
    expect(xSlider.max, 100);
    expect(ySlider.max, 100);

    await tester.tap(find.text('发送摇杆命令'));
    await tester.pump();

    expect(tcpClient.sent.last, CarEncoder.rocker(0, 0));
  });

  testWidgets('remote car page keeps wheel speeds in advanced debug',
      (tester) async {
    final tcpClient = _FakeTcpClient();
    await tester.pumpWidget(
      MaterialApp(
        home: ChildRemoteCarPage(
          tcpClient: tcpClient,
          mjpegBuilder: (_, __) => const SizedBox(key: Key('fakeMjpeg')),
        ),
      ),
    );

    await tester.tap(find.text('连接 TCP'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('高级调试'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('高级调试'), findsOneWidget);
    expect(find.text('发送四轮速度'), findsNothing);

    await tester.tap(find.text('高级调试'));
    await tester.pumpAndSettle();

    expect(find.text('发送四轮速度'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('发送四轮速度'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('发送四轮速度'));
    await tester.pump();

    expect(tcpClient.sent.last, CarEncoder.wheelSpeeds(0, 0, 0, 0));
  });
}

class _FakeTcpClient extends CarTcpClient {
  bool connected = false;
  String? host;
  int? port;
  final sent = <String>[];

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect(String host, int port) async {
    this.host = host;
    this.port = port;
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

class _FailingTcpClient extends CarTcpClient {
  @override
  Future<void> connect(String host, int port) async {
    throw Exception('offline');
  }
}
