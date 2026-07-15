import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../inspection_map/data/rosbridge_navigation_client.dart';
import '../../inspection_map/models/map_info.dart';
import '../../inspection_map/models/ros_navigation_models.dart';
import '../../inspection_map/utils/coordinate_converter.dart';
import '../application/employee_round_trip_controller.dart';
import '../data/backend_round_trip_api.dart';
import '../data/employee_round_trip_command_gateway.dart';
import '../models/employee_round_trip_state.dart';
import '../models/round_trip_backend_models.dart';

enum _PoseMode { initialPose, target }

class EmployeeRoundTripInspectionPage extends StatefulWidget {
  const EmployeeRoundTripInspectionPage({
    super.key,
    this.initialUrl = const String.fromEnvironment(
      'ROSBRIDGE_URL',
      defaultValue: 'ws://10.137.172.125:9090',
    ),
    this.autoConnect = const bool.fromEnvironment(
      'ROSBRIDGE_AUTO_CONNECT',
      defaultValue: true,
    ),
    this.rosClient,
    this.commandMode,
    this.commandGateway,
    this.backendApi,
    this.robotId = const int.fromEnvironment(
      'ROUND_TRIP_ROBOT_ID',
      defaultValue: 1,
    ),
    this.mapId = const int.fromEnvironment(
      'ROUND_TRIP_MAP_ID',
      defaultValue: 1,
    ),
    this.mapRevision = const String.fromEnvironment(
      'ROUND_TRIP_MAP_REVISION',
      defaultValue: 'yahboomcar-static-v1',
    ),
    this.backendPollInterval = const Duration(seconds: 2),
  });

  final String initialUrl;
  final bool autoConnect;
  final RosbridgeNavigationClient? rosClient;
  final RoundTripCommandMode? commandMode;
  final EmployeeRoundTripCommandGateway? commandGateway;
  final BackendRoundTripApi? backendApi;
  final int robotId;
  final int mapId;
  final String mapRevision;
  final Duration backendPollInterval;

  @override
  State<EmployeeRoundTripInspectionPage> createState() =>
      _EmployeeRoundTripInspectionPageState();
}

class _EmployeeRoundTripInspectionPageState
    extends State<EmployeeRoundTripInspectionPage> {
  static const _mapInfo = MapInfo(
    mapName: 'yahboomcar',
    imageAsset: 'assets/robot_maps/yahboomcar.png',
    imageFile: 'yahboomcar.png',
    width: 864,
    height: 896,
    imageHeight: 896,
    resolution: 0.05,
    origin: [-22.8, -22.8, 0],
    frameId: 'map',
  );

  late final RosbridgeNavigationClient _rosClient;
  late final bool _ownsClient;
  late final RoundTripCommandMode _commandMode;
  late final EmployeeRoundTripCommandGateway _commandGateway;
  late final EmployeeRoundTripController _controller;
  StreamSubscription<RosbridgeConnectionEvent>? _connectionSubscription;
  StreamSubscription<RosbridgeTopicMessage>? _messageSubscription;

  RosbridgeConnectionStatus _connectionStatus =
      RosbridgeConnectionStatus.disconnected;
  String? _connectionMessage;
  _PoseMode _poseMode = _PoseMode.initialPose;
  RosPose2D? _initialPose;
  double _selectedYaw = 0;
  bool _initialPoseSent = false;

  bool get _isConnected =>
      _connectionStatus == RosbridgeConnectionStatus.connected;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.rosClient == null;
    _rosClient = widget.rosClient ?? RosbridgeNavigationClient();
    _commandMode = widget.commandGateway?.mode ??
        widget.commandMode ??
        RoundTripCommandMode.parse(
          const String.fromEnvironment(
            'ROUND_TRIP_COMMAND_TRANSPORT',
            defaultValue: 'direct_rosbridge',
          ),
        );
    _commandGateway = widget.commandGateway ??
        switch (_commandMode) {
          RoundTripCommandMode.directRosbridge =>
            DirectRosbridgeRoundTripGateway(_rosClient),
          RoundTripCommandMode.backendMediated =>
            BackendMediatedRoundTripGateway(
              api: widget.backendApi ?? DioBackendRoundTripApi(),
              robotId: widget.robotId,
              map: RoundTripMapPayload(
                mapId: widget.mapId,
                mapRevision: widget.mapRevision,
                mapName: _mapInfo.mapName,
                width: _mapInfo.width,
                height: _mapInfo.height,
                resolution: _mapInfo.resolution,
                origin: _mapInfo.origin,
                frameId: _mapInfo.frameId,
              ),
              autoReturnDelay: const Duration(seconds: 2),
            ),
        };
    _controller = EmployeeRoundTripController(
      commandGateway: _commandGateway,
      backendPollInterval: widget.backendPollInterval,
    )..addListener(_handleControllerChanged);
    _connectionSubscription =
        _rosClient.connectionEvents.listen(_handleConnectionEvent);
    _messageSubscription = _rosClient.messages.listen(_handleRosMessage);
    if (widget.autoConnect) {
      unawaited(_rosClient.connect(widget.initialUrl));
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    if (_ownsClient) unawaited(_rosClient.dispose());
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleConnectionEvent(RosbridgeConnectionEvent event) {
    if (!mounted) return;
    final wasConnected = _isConnected;
    setState(() {
      _connectionStatus = event.status;
      _connectionMessage = event.message;
    });
    if (wasConnected && event.status != RosbridgeConnectionStatus.connected) {
      _controller.invalidatePose();
      _controller.handleDisconnect();
    }
  }

  void _handleRosMessage(RosbridgeTopicMessage event) {
    try {
      switch (event.topic) {
        case '/amcl_pose':
          final header = _asMap(event.message['header']);
          final poseWithCovariance = _asMap(event.message['pose']);
          final pose = _asMap(poseWithCovariance['pose']);
          if (pose.isNotEmpty) {
            _controller.updatePose(
              RosPose2D.fromPose(
                pose,
                frameId: '${header['frame_id'] ?? 'map'}',
              ),
            );
          }
        case '/navigate_to_pose/_action/status':
          _controller.handleActionStatus(event.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _connectionMessage = '${event.topic}: $error');
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _rosClient.disconnect();
    } else {
      await _rosClient.connect(widget.initialUrl);
    }
  }

  void _handleMapTap(TapDownDetails details, Size size) {
    if (_controller.state.isBusy || _controller.state.commandPending) return;
    final pixelX = details.localPosition.dx / size.width * _mapInfo.width;
    final pixelY = details.localPosition.dy / size.height * _mapInfo.height;
    if (pixelX < 0 ||
        pixelY < 0 ||
        pixelX > _mapInfo.width ||
        pixelY > _mapInfo.height) {
      return;
    }
    final mapPoint = pixelToMap(pixelX, pixelY, _mapInfo);
    final pose = RosPose2D(
      x: mapPoint.x,
      y: mapPoint.y,
      yaw: _selectedYaw,
    );
    if (_poseMode == _PoseMode.initialPose) {
      setState(() {
        _initialPose = pose;
        _initialPoseSent = false;
      });
    } else {
      _controller.selectTarget(pose);
    }
  }

  void _setYaw(double yaw) {
    final normalized = normalizeYaw(yaw);
    if (_poseMode == _PoseMode.initialPose) {
      setState(() {
        _selectedYaw = normalized;
        if (_initialPose == null) return;
        _initialPose = RosPose2D(
          x: _initialPose!.x,
          y: _initialPose!.y,
          yaw: normalized,
        );
        _initialPoseSent = false;
      });
      return;
    }
    setState(() => _selectedYaw = normalized);
    final target = _controller.state.target;
    if (target != null) {
      _controller.selectTarget(
        RosPose2D(x: target.x, y: target.y, yaw: normalized),
      );
    }
  }

  Future<void> _publishInitialPose() async {
    final pose = _initialPose;
    if (!_isConnected || pose == null) return;
    final sent = await _controller.setInitialPose(pose);
    if (mounted && sent) setState(() => _initialPoseSent = true);
  }

  Future<void> _confirmOutbound() async {
    final target = _controller.state.target;
    if (target == null || !_isConnected) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('开始往返巡检？'),
            content: Text(
              '小车将前往 (${target.x.toStringAsFixed(2)}, '
              '${target.y.toStringAsFixed(2)})，到达后自动返回记录的起点。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _controller.startOutbound();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('往返巡检'),
        actions: [
          IconButton(
            key: const ValueKey('employee-round-trip-connect'),
            tooltip: _isConnected ? '断开 ROS 遥测' : '连接 ROS 遥测',
            onPressed: _connectionStatus == RosbridgeConnectionStatus.connecting
                ? null
                : _toggleConnection,
            icon: Icon(_isConnected ? Icons.link_off : Icons.link),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatus(state),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      children: [
                        Expanded(child: _buildMap(state)),
                        SizedBox(width: 360, child: _buildControls(state)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: _buildMap(state)),
                      SizedBox(height: 350, child: _buildControls(state)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(EmployeeRoundTripState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: _isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _isConnected
                    ? (_commandMode == RoundTripCommandMode.directRosbridge
                        ? '机器人已连接'
                        : 'ROS 遥测已连接')
                    : (_commandMode == RoundTripCommandMode.directRosbridge
                        ? '机器人未连接'
                        : 'ROS 遥测未连接'),
                key: const ValueKey('employee-round-trip-connection-status'),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _commandMode == RoundTripCommandMode.directRosbridge
                    ? Icons.cable
                    : Icons.cloud_outlined,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '控制：${_commandMode.label}',
                key: const ValueKey('employee-round-trip-command-mode'),
              ),
            ],
          ),
          Text(
            state.phase.label,
            key: const ValueKey('employee-round-trip-phase'),
          ),
          if (state.backendTaskId != null)
            Text(
              'Task ${state.backendTaskId}',
              key: const ValueKey('employee-round-trip-task-id'),
            ),
          if (state.backendStatus != null) Text(state.backendStatus!),
          if (state.message != null) Text(state.message!),
          if (_connectionMessage != null) Text(_connectionMessage!),
        ],
      ),
    );
  }

  Widget _buildMap(EmployeeRoundTripState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: _mapInfo.width / _mapInfo.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                key: const ValueKey('employee-round-trip-map'),
                onTapDown: (details) => _handleMapTap(details, size),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(_mapInfo.imageAsset, fit: BoxFit.fill),
                    if (_initialPose != null)
                      _buildMarker(
                        _initialPose!,
                        size,
                        Icons.my_location,
                        Colors.orange,
                        '初始位置',
                      ),
                    if (state.latestPose != null)
                      _buildMarker(
                        state.latestPose!,
                        size,
                        Icons.navigation,
                        Colors.green.shade700,
                        '小车',
                      ),
                    if (state.home != null)
                      _buildMarker(
                        state.home!,
                        size,
                        Icons.home,
                        Colors.blue.shade700,
                        '返航点',
                      ),
                    if (state.target != null)
                      _buildMarker(
                        state.target!,
                        size,
                        Icons.flag,
                        Colors.red.shade700,
                        '巡检目标',
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(
    RosPose2D pose,
    Size size,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    final pixel = mapToPixel(pose.x, pose.y, _mapInfo);
    return Positioned(
      left: pixel.x / _mapInfo.width * size.width - 15,
      top: pixel.y / _mapInfo.height * size.height - 15,
      width: 30,
      height: 30,
      child: Tooltip(
        message: tooltip,
        child: Transform.rotate(
          angle: icon == Icons.navigation ? -pose.yaw + math.pi / 2 : 0,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }

  Widget _buildControls(EmployeeRoundTripState state) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<_PoseMode>(
          key: const ValueKey('employee-round-trip-pose-mode'),
          segments: const [
            ButtonSegment(
              value: _PoseMode.initialPose,
              icon: Icon(Icons.my_location),
              label: Text('起点'),
            ),
            ButtonSegment(
              value: _PoseMode.target,
              icon: Icon(Icons.flag),
              label: Text(
                '目标',
                key: ValueKey('employee-round-trip-target-mode'),
              ),
            ),
          ],
          selected: {_poseMode},
          onSelectionChanged: state.isBusy || state.commandPending
              ? null
              : (selection) => setState(() => _poseMode = selection.first),
        ),
        const SizedBox(height: 8),
        Text('方向：${_selectedYaw.toStringAsFixed(2)} rad'),
        Slider(
          key: const ValueKey('employee-round-trip-yaw'),
          min: -math.pi,
          max: math.pi,
          value: _selectedYaw,
          onChanged: state.isBusy || state.commandPending ? null : _setYaw,
        ),
        _PoseSummary(label: '初始', pose: _initialPose),
        _PoseSummary(label: 'AMCL', pose: state.latestPose),
        _PoseSummary(label: '返航点', pose: state.home),
        _PoseSummary(label: '目标点', pose: state.target),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('employee-round-trip-set-start'),
          onPressed: _isConnected &&
                  _initialPose != null &&
                  !state.isBusy &&
                  !state.commandPending
              ? _publishInitialPose
              : null,
          icon: const Icon(Icons.my_location),
          label: Text(
            state.commandPending
                ? '正在提交'
                : (_initialPoseSent ? '初始位置已发送' : '设置初始位置'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('employee-round-trip-capture-home'),
          onPressed: _isConnected && !state.isBusy && !state.commandPending
              ? _controller.captureHome
              : null,
          icon: const Icon(Icons.home),
          label: const Text('记录返航点'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('employee-round-trip-go'),
          onPressed:
              _isConnected && state.canStartOutbound ? _confirmOutbound : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            _commandMode == RoundTripCommandMode.directRosbridge
                ? '开始往返巡检'
                : '提交后端往返任务',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('employee-round-trip-stop'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: state.canStop &&
                  (_isConnected ||
                      _commandMode == RoundTripCommandMode.backendMediated)
              ? () => unawaited(_controller.stop())
              : null,
          icon: const Icon(Icons.stop),
          label: Text(
            _commandMode == RoundTripCommandMode.directRosbridge
                ? '停止'
                : '停止后端任务',
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const ValueKey('employee-round-trip-reset'),
          onPressed: state.isBusy || state.commandPending
              ? null
              : _controller.resetTrip,
          icon: const Icon(Icons.restart_alt),
          label: const Text('重置本次往返'),
        ),
      ],
    );
  }
}

class _PoseSummary extends StatelessWidget {
  const _PoseSummary({required this.label, required this.pose});

  final String label;
  final RosPose2D? pose;

  @override
  Widget build(BuildContext context) {
    final value = pose == null
        ? '--'
        : '${pose!.x.toStringAsFixed(2)}, ${pose!.y.toStringAsFixed(2)}, '
            '${pose!.yaw.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 58, child: Text(label)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
