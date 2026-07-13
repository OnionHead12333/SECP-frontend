import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../../data/remote_car/car_encoder.dart';
import '../../data/remote_car/car_tcp_client.dart';
import '../../data/remote_car/remote_car_models.dart';

typedef MjpegWidgetBuilder = Widget Function(
  BuildContext context,
  String streamUrl,
);

class ChildRemoteCarPage extends StatefulWidget {
  const ChildRemoteCarPage({
    super.key,
    CarTcpClient? tcpClient,
    MjpegWidgetBuilder? mjpegBuilder,
  })  : _tcpClient = tcpClient,
        _mjpegBuilder = mjpegBuilder;

  final CarTcpClient? _tcpClient;
  final MjpegWidgetBuilder? _mjpegBuilder;

  @override
  State<ChildRemoteCarPage> createState() => _ChildRemoteCarPageState();
}

class _ChildRemoteCarPageState extends State<ChildRemoteCarPage> {
  static const String _defaultCarIp = '10.40.70.125';
  static const int _defaultControlPort = 6000;
  static const String _videoFailureMessage =
      '视频连接失败，请确认小车端已运行 python3 app.py，且 6500 端口可访问';
  static const String _controlFailureMessage =
      '小车控制连接失败，请确认 app.py 已启动，6000 端口可访问';

  late final CarTcpClient _tcpClient;
  late final TextEditingController _carIpController;

  String _connectionStatus = 'TCP未连接';
  String _lastCommand = '-';
  String? _errorText;
  int _speedLimit = 60;
  double _rockerX = 0;
  double _rockerY = 0;
  double _leftFrontSpeed = 0;
  double _leftRearSpeed = 0;
  double _rightFrontSpeed = 0;
  double _rightRearSpeed = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tcpClient = widget._tcpClient ?? CarTcpClient();
    _carIpController = TextEditingController(text: _defaultCarIp);
  }

  @override
  void dispose() {
    _carIpController.dispose();
    _tcpClient.close();
    super.dispose();
  }

  String get _carIp => _carIpController.text.trim();

  String get _videoStreamUrl => 'http://$_carIp:6500/video_feed';

  Future<void> _connectTcp() async {
    if (_carIp.isEmpty) {
      _showControlFailure();
      return;
    }
    await _runAction(
      () async {
        await _tcpClient.connect(_carIp, _defaultControlPort);
        setState(() {
          _connectionStatus = 'TCP已连接 $_carIp:$_defaultControlPort';
          _errorText = null;
        });
      },
      failureMessage: _controlFailureMessage,
    );
  }

  Future<void> _disconnectTcp() async {
    await _runAction(() async {
      await _tcpClient.close();
      setState(() => _connectionStatus = 'TCP已断开');
    });
  }

  Future<void> _sendCommand(RemoteCarCommand command) async {
    if (!_tcpClient.isConnected) {
      _showControlFailure();
      return;
    }
    await _runAction(
      () async {
        await _tcpClient.send(CarEncoder.button(command.tcpDirection));
        setState(() {
          _lastCommand = command.label;
          _errorText = null;
        });
      },
      failureMessage: _controlFailureMessage,
    );
  }

  Future<void> _sendRocker({bool resetAfterSend = false}) async {
    if (!_tcpClient.isConnected) {
      _showControlFailure();
      return;
    }
    final x = _rockerX.round().clamp(-_speedLimit, _speedLimit);
    final y = _rockerY.round().clamp(-_speedLimit, _speedLimit);
    await _runAction(
      () async {
        await _tcpClient.send(CarEncoder.rocker(x, y));
        setState(() {
          _lastCommand = '摇杆 x=$x y=$y';
          _errorText = null;
          if (resetAfterSend) {
            _rockerX = 0;
            _rockerY = 0;
          }
        });
      },
      failureMessage: _controlFailureMessage,
    );
  }

  Future<void> _sendWheelSpeeds() async {
    if (!_tcpClient.isConnected) {
      _showControlFailure();
      return;
    }
    await _runAction(
      () async {
        await _tcpClient.send(
          CarEncoder.wheelSpeeds(
            _leftFrontSpeed,
            _leftRearSpeed,
            _rightFrontSpeed,
            _rightRearSpeed,
          ),
        );
        setState(() {
          _lastCommand = '四轮速度';
          _errorText = null;
        });
      },
      failureMessage: _controlFailureMessage,
    );
  }

  void _setSpeedLimit(int value) {
    setState(() {
      _speedLimit = value;
      _rockerX = _rockerX.clamp(-value, value).toDouble();
      _rockerY = _rockerY.clamp(-value, value).toDouble();
    });
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? failureMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _showSnack(failureMessage ?? _controlFailureMessage);
      if (mounted) {
        setState(() => _errorText = failureMessage ?? _controlFailureMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showControlFailure() {
    _showSnack(_controlFailureMessage);
    setState(() => _errorText = _controlFailureMessage);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('远程控车')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _TcpConfigCard(
            ipController: _carIpController,
            connected: _tcpClient.isConnected,
            onIpChanged: () => setState(() {}),
            onConnect: _busy ? null : _connectTcp,
            onDisconnect: _busy ? null : _disconnectTcp,
          ),
          const SizedBox(height: 14),
          _StatusCard(
            connectionStatus: _connectionStatus,
            lastCommand: _lastCommand,
            busy: _busy,
          ),
          const SizedBox(height: 14),
          _VideoCard(
            streamUrl: _videoStreamUrl,
            failureMessage: _videoFailureMessage,
            mjpegBuilder: widget._mjpegBuilder,
          ),
          const SizedBox(height: 14),
          _ControlPad(
            busy: _busy,
            onCommand: _sendCommand,
          ),
          const SizedBox(height: 14),
          _RockerControlCard(
            busy: _busy,
            speedLimit: _speedLimit,
            rockerX: _rockerX,
            rockerY: _rockerY,
            onSpeedChanged: _setSpeedLimit,
            onXChanged: (value) => setState(() => _rockerX = value),
            onYChanged: (value) => setState(() => _rockerY = value),
            onSend: _busy ? null : () => _sendRocker(),
          ),
          const SizedBox(height: 14),
          _AdvancedDebugCard(
            busy: _busy,
            speedLimit: _speedLimit,
            leftFront: _leftFrontSpeed,
            leftRear: _leftRearSpeed,
            rightFront: _rightFrontSpeed,
            rightRear: _rightRearSpeed,
            onLeftFrontChanged: (value) =>
                setState(() => _leftFrontSpeed = value),
            onLeftRearChanged: (value) => setState(() => _leftRearSpeed = value),
            onRightFrontChanged: (value) =>
                setState(() => _rightFrontSpeed = value),
            onRightRearChanged: (value) =>
                setState(() => _rightRearSpeed = value),
            onSend: _busy ? null : _sendWheelSpeeds,
          ),
          const SizedBox(height: 14),
          _ErrorPanel(errorText: _errorText),
        ],
      ),
    );
  }
}

class _RockerControlCard extends StatelessWidget {
  const _RockerControlCard({
    required this.busy,
    required this.speedLimit,
    required this.rockerX,
    required this.rockerY,
    required this.onSpeedChanged,
    required this.onXChanged,
    required this.onYChanged,
    required this.onSend,
  });

  final bool busy;
  final int speedLimit;
  final double rockerX;
  final double rockerY;
  final ValueChanged<int> onSpeedChanged;
  final ValueChanged<double> onXChanged;
  final ValueChanged<double> onYChanged;
  final VoidCallback? onSend;

  String get _speedLabel {
    return switch (speedLimit) {
      30 => '慢速 30',
      100 => '快速 100',
      _ => '中速 60',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gamepad_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('虚拟摇杆', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('慢速')),
                ButtonSegment(value: 60, label: Text('中速')),
                ButtonSegment(value: 100, label: Text('快速')),
              ],
              selected: {speedLimit},
              onSelectionChanged:
                  busy ? null : (values) => onSpeedChanged(values.first),
            ),
            const SizedBox(height: 8),
            Text(
              _speedLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _SignedSlider(
              sliderKey: const Key('rockerXSlider'),
              label: 'X：左转 / 右转',
              value: rockerX,
              limit: speedLimit,
              onChanged: busy ? null : onXChanged,
            ),
            _SignedSlider(
              sliderKey: const Key('rockerYSlider'),
              label: 'Y：后退 / 前进',
              value: rockerY,
              limit: speedLimit,
              onChanged: busy ? null : onYChanged,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send),
                label: const Text('发送摇杆命令'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedDebugCard extends StatelessWidget {
  const _AdvancedDebugCard({
    required this.busy,
    required this.speedLimit,
    required this.leftFront,
    required this.leftRear,
    required this.rightFront,
    required this.rightRear,
    required this.onLeftFrontChanged,
    required this.onLeftRearChanged,
    required this.onRightFrontChanged,
    required this.onRightRearChanged,
    required this.onSend,
  });

  final bool busy;
  final int speedLimit;
  final double leftFront;
  final double leftRear;
  final double rightFront;
  final double rightRear;
  final ValueChanged<double> onLeftFrontChanged;
  final ValueChanged<double> onLeftRearChanged;
  final ValueChanged<double> onRightFrontChanged;
  final ValueChanged<double> onRightRearChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ExpansionTile(
        title: const Text('高级调试'),
        leading: const Icon(Icons.tune),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          _SignedSlider(
            label: '左前轮',
            value: leftFront,
            limit: speedLimit,
            onChanged: busy ? null : onLeftFrontChanged,
          ),
          _SignedSlider(
            label: '左后轮',
            value: leftRear,
            limit: speedLimit,
            onChanged: busy ? null : onLeftRearChanged,
          ),
          _SignedSlider(
            label: '右前轮',
            value: rightFront,
            limit: speedLimit,
            onChanged: busy ? null : onRightFrontChanged,
          ),
          _SignedSlider(
            label: '右后轮',
            value: rightRear,
            limit: speedLimit,
            onChanged: busy ? null : onRightRearChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.memory),
              label: const Text('发送四轮速度'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedSlider extends StatelessWidget {
  const _SignedSlider({
    this.sliderKey,
    required this.label,
    required this.value,
    required this.limit,
    required this.onChanged,
  });

  final Key? sliderKey;
  final String label;
  final double value;
  final int limit;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.round().toString()),
          ],
        ),
        Slider(
          key: sliderKey,
          value: value.clamp(-limit, limit).toDouble(),
          min: -limit.toDouble(),
          max: limit.toDouble(),
          divisions: limit * 2,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TcpConfigCard extends StatelessWidget {
  const _TcpConfigCard({
    required this.ipController,
    required this.connected,
    required this.onIpChanged,
    required this.onConnect,
    required this.onDisconnect,
  });

  final TextEditingController ipController;
  final bool connected;
  final VoidCallback onIpChanged;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('小车连接', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              key: const Key('carIpField'),
              controller: ipController,
              decoration: const InputDecoration(
                labelText: '小车 IP',
                hintText: '10.40.70.125',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) => onIpChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: connected ? null : onConnect,
                    icon: const Icon(Icons.link),
                    label: const Text('连接 TCP'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: connected ? onDisconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('断开'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connectionStatus,
    required this.lastCommand,
    required this.busy,
  });

  final String connectionStatus;
  final String lastCommand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(busy ? Icons.sync : Icons.settings_ethernet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(connectionStatus,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('最近命令：$lastCommand'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.streamUrl,
    required this.failureMessage,
    this.mjpegBuilder,
  });

  final String streamUrl;
  final String failureMessage;
  final MjpegWidgetBuilder? mjpegBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = mjpegBuilder?.call(context, streamUrl) ??
        Mjpeg(
          key: const Key('mjpegVideo'),
          stream: streamUrl,
          isLive: true,
          fit: BoxFit.cover,
          loading: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (context, error, stack) => _VideoErrorText(
            message: failureMessage,
          ),
        );
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('实时视频', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '视频服务需要小车端已运行 python3 app.py。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SelectableText(
              streamUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoErrorText extends StatelessWidget {
  const _VideoErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _ControlPad extends StatelessWidget {
  const _ControlPad({
    required this.busy,
    required this.onCommand,
  });

  final bool busy;
  final Future<void> Function(RemoteCarCommand command) onCommand;

  bool _canSend(RemoteCarCommand command) {
    return !busy;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _CommandButton(
              icon: Icons.keyboard_arrow_up,
              label: '前进',
              command: RemoteCarCommand.forward,
              canSend: _canSend,
              onCommand: onCommand,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CommandButton(
                    icon: Icons.keyboard_arrow_left,
                    label: '左转',
                    command: RemoteCarCommand.left,
                    canSend: _canSend,
                    onCommand: onCommand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommandButton(
                    icon: Icons.keyboard_arrow_right,
                    label: '右转',
                    command: RemoteCarCommand.right,
                    canSend: _canSend,
                    onCommand: onCommand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CommandButton(
              icon: Icons.keyboard_arrow_down,
              label: '后退',
              command: RemoteCarCommand.backward,
              canSend: _canSend,
              onCommand: onCommand,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CommandButton(
                    icon: Icons.stop_circle_outlined,
                    label: '停止',
                    command: RemoteCarCommand.stop,
                    canSend: _canSend,
                    onCommand: onCommand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _canSend(RemoteCarCommand.emergencyStop)
                        ? () => onCommand(RemoteCarCommand.emergencyStop)
                        : null,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('紧急停止'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.label,
    required this.command,
    required this.canSend,
    required this.onCommand,
  });

  final IconData icon;
  final String label;
  final RemoteCarCommand command;
  final bool Function(RemoteCarCommand command) canSend;
  final Future<void> Function(RemoteCarCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: canSend(command) ? () => onCommand(command) : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final text = errorText;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
