import 'package:flutter/material.dart';

import '../../data/remote_car/car_encoder.dart';
import '../../data/remote_car/car_tcp_client.dart';
import '../../data/remote_car/child_remote_car_gateway_client.dart';
import '../../data/remote_car/remote_car_models.dart';

class ChildRemoteCarPage extends StatefulWidget {
  const ChildRemoteCarPage({
    super.key,
    ChildRemoteCarGatewayClient? gatewayClient,
    CarTcpClient? tcpClient,
  })  : _gatewayClient = gatewayClient,
        _tcpClient = tcpClient;

  final ChildRemoteCarGatewayClient? _gatewayClient;
  final CarTcpClient? _tcpClient;

  @override
  State<ChildRemoteCarPage> createState() => _ChildRemoteCarPageState();
}

class _ChildRemoteCarPageState extends State<ChildRemoteCarPage> {
  late final ChildRemoteCarGatewayClient _gatewayClient;
  late final CarTcpClient _tcpClient;
  late final TextEditingController _gatewayBaseUrlController;
  late final TextEditingController _carIpController;
  late final TextEditingController _carPortController;

  RemoteCarMode _mode = RemoteCarMode.ros2Gateway;
  RosCarState? _gatewayState;
  String _connectionStatus = '未连接';
  String _lastCommand = '-';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gatewayClient = widget._gatewayClient ?? ChildRemoteCarGatewayClient();
    _tcpClient = widget._tcpClient ?? CarTcpClient();
    _gatewayBaseUrlController = TextEditingController();
    _carIpController = TextEditingController();
    _carPortController = TextEditingController(text: '6000');
  }

  @override
  void dispose() {
    _gatewayBaseUrlController.dispose();
    _carIpController.dispose();
    _carPortController.dispose();
    _tcpClient.close();
    super.dispose();
  }

  Future<void> _connectTcp() async {
    final host = _carIpController.text.trim();
    final port = int.tryParse(_carPortController.text.trim());
    if (host.isEmpty || port == null) {
      _showSnack('请填写正确的小车 IP 和端口');
      return;
    }
    await _runAction(() async {
      await _tcpClient.connect(host, port);
      setState(() => _connectionStatus = 'TCP已连接 $host:$port');
    });
  }

  Future<void> _disconnectTcp() async {
    await _runAction(() async {
      await _tcpClient.close();
      setState(() => _connectionStatus = 'TCP已断开');
    });
  }

  Future<void> _refreshGatewayState() async {
    final gatewayBaseUrl = _gatewayBaseUrlController.text.trim();
    if (gatewayBaseUrl.isEmpty) {
      _showSnack('请填写 gatewayBaseUrl');
      return;
    }
    await _runAction(() async {
      final state = await _gatewayClient.fetchState(
        gatewayBaseUrl: gatewayBaseUrl,
      );
      setState(() {
        _gatewayState = state;
        _connectionStatus = state.controlConnected ? 'ROS2控制已连接' : 'ROS2控制未连接';
      });
    });
  }

  Future<void> _sendCommand(RemoteCarCommand command) async {
    if (_mode == RemoteCarMode.tcpDirect) {
      final direction = command.tcpDirection;
      if (direction == null) return;
      if (!_tcpClient.isConnected) {
        _showSnack('请先连接小车 TCP');
        return;
      }
      await _runAction(() async {
        await _tcpClient.send(CarEncoder.button(direction));
        setState(() => _lastCommand = command.gatewayValue);
      });
      return;
    }

    final gatewayBaseUrl = _gatewayBaseUrlController.text.trim();
    if (gatewayBaseUrl.isEmpty) {
      _showSnack('请填写 gatewayBaseUrl');
      return;
    }
    await _runAction(() async {
      await _gatewayClient.sendCommand(
        gatewayBaseUrl: gatewayBaseUrl,
        command: command,
      );
      final state = await _gatewayClient.fetchState(
        gatewayBaseUrl: gatewayBaseUrl,
      );
      setState(() {
        _lastCommand = command.gatewayValue;
        _gatewayState = state;
        _connectionStatus = state.controlConnected ? 'ROS2控制已连接' : 'ROS2控制未连接';
      });
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showSnack('控制失败：$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _canSend(RemoteCarCommand command) {
    if (_busy) return false;
    if (_mode == RemoteCarMode.tcpDirect &&
        command == RemoteCarCommand.resetEmergency) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('远程控车')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SegmentedButton<RemoteCarMode>(
            segments: const [
              ButtonSegment(
                value: RemoteCarMode.ros2Gateway,
                icon: Icon(Icons.hub_outlined),
                label: Text('ROS2网关'),
              ),
              ButtonSegment(
                value: RemoteCarMode.tcpDirect,
                icon: Icon(Icons.settings_ethernet),
                label: Text('TCP直连'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 14),
          if (_mode == RemoteCarMode.ros2Gateway)
            _GatewayConfigCard(
              controller: _gatewayBaseUrlController,
              onRefresh: _busy ? null : _refreshGatewayState,
            )
          else
            _TcpConfigCard(
              ipController: _carIpController,
              portController: _carPortController,
              connected: _tcpClient.isConnected,
              onConnect: _busy ? null : _connectTcp,
              onDisconnect: _busy ? null : _disconnectTcp,
            ),
          const SizedBox(height: 14),
          _StatusCard(
            connectionStatus: _connectionStatus,
            lastCommand: _lastCommand,
            busy: _busy,
          ),
          if (_mode == RemoteCarMode.ros2Gateway) ...[
            const SizedBox(height: 14),
            _GatewayStateCard(state: _gatewayState, scheme: scheme),
          ],
          const SizedBox(height: 14),
          _ControlPad(
            canSend: _canSend,
            onCommand: _sendCommand,
          ),
        ],
      ),
    );
  }
}

class _GatewayConfigCard extends StatelessWidget {
  const _GatewayConfigCard({
    required this.controller,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ROS2网关配置', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              key: const Key('gatewayBaseUrlField'),
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'gatewayBaseUrl',
                hintText: 'http://192.168.1.10:9090',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新状态'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TcpConfigCard extends StatelessWidget {
  const _TcpConfigCard({
    required this.ipController,
    required this.portController,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final TextEditingController ipController;
  final TextEditingController portController;
  final bool connected;
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
            Text('TCP直连配置', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: '小车 IP',
                hintText: '192.168.1.50',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: '端口',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: connected ? null : onConnect,
                    icon: const Icon(Icons.link),
                    label: const Text('连接'),
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
            Icon(busy ? Icons.sync : Icons.sensors),
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

class _ControlPad extends StatelessWidget {
  const _ControlPad({
    required this.canSend,
    required this.onCommand,
  });

  final bool Function(RemoteCarCommand command) canSend;
  final Future<void> Function(RemoteCarCommand command) onCommand;

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
              canSend: canSend,
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
                    canSend: canSend,
                    onCommand: onCommand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommandButton(
                    icon: Icons.stop_circle_outlined,
                    label: '停止',
                    command: RemoteCarCommand.stop,
                    canSend: canSend,
                    onCommand: onCommand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommandButton(
                    icon: Icons.keyboard_arrow_right,
                    label: '右转',
                    command: RemoteCarCommand.right,
                    canSend: canSend,
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
              canSend: canSend,
              onCommand: onCommand,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: canSend(RemoteCarCommand.emergencyStop)
                        ? () => onCommand(RemoteCarCommand.emergencyStop)
                        : null,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('紧急停止'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canSend(RemoteCarCommand.resetEmergency)
                        ? () => onCommand(RemoteCarCommand.resetEmergency)
                        : null,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('解除急停'),
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

class _GatewayStateCard extends StatelessWidget {
  const _GatewayStateCard({
    required this.state,
    required this.scheme,
  });

  final RosCarState? state;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final fields = state?.displayFields;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ROS2状态', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (fields == null)
              Text(
                '暂无状态，填写 gatewayBaseUrl 后刷新',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...fields.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
