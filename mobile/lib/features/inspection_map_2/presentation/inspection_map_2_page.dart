import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../inspection_map/data/rosbridge_navigation_client.dart';
import '../../inspection_map/models/map_info.dart';
import '../../inspection_map/models/ros_navigation_models.dart';
import '../../inspection_map/utils/coordinate_converter.dart';
import '../application/round_trip_navigation_controller.dart';
import '../models/round_trip_navigation_state.dart';

enum _Map2PoseMode { initialPose, target }

class InspectionMap2Page extends StatefulWidget {
  const InspectionMap2Page({
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
  });

  final String initialUrl;
  final bool autoConnect;
  final RosbridgeNavigationClient? rosClient;

  @override
  State<InspectionMap2Page> createState() => _InspectionMap2PageState();
}

class _InspectionMap2PageState extends State<InspectionMap2Page> {
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
  late final RoundTripNavigationController _controller;
  late final TextEditingController _urlController;
  StreamSubscription<RosbridgeConnectionEvent>? _connectionSubscription;
  StreamSubscription<RosbridgeTopicMessage>? _messageSubscription;

  RosbridgeConnectionStatus _connectionStatus =
      RosbridgeConnectionStatus.disconnected;
  String? _connectionMessage;
  _Map2PoseMode _poseMode = _Map2PoseMode.initialPose;
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
    _urlController = TextEditingController(text: widget.initialUrl);
    _controller = RoundTripNavigationController(
      poseMaxAge: const Duration(days: 1),
      publishGoal: (pose) => _rosClient.publishGoalPose(
        x: pose.x,
        y: pose.y,
        yaw: pose.yaw,
      ),
      publishStop: _rosClient.stopNavigation,
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
    _urlController.dispose();
    if (_ownsClient) unawaited(_rosClient.dispose());
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
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
      await _rosClient.connect(_urlController.text);
    }
  }

  void _handleMapTap(TapDownDetails details, Size size) {
    if (_controller.state.isBusy) return;
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
    if (_poseMode == _Map2PoseMode.initialPose) {
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
    if (_poseMode == _Map2PoseMode.initialPose) {
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

  void _publishInitialPose() {
    final pose = _initialPose;
    if (!_isConnected || pose == null) return;
    _controller.invalidatePose();
    _rosClient.publishInitialPose(x: pose.x, y: pose.y, yaw: pose.yaw);
    setState(() => _initialPoseSent = true);
  }

  Future<void> _confirmOutbound() async {
    final target = _controller.state.target;
    if (target == null || !_isConnected) return;
    final confirmed = await _confirmCommand(
      title: 'Navigate to destination?',
      body: 'Send one goal to x=${target.x.toStringAsFixed(2)}, '
          'y=${target.y.toStringAsFixed(2)}?',
      confirmLabel: 'Go',
    );
    if (confirmed) _controller.startOutbound();
  }

  Future<bool> _confirmCommand({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Map 2 - Round Trip')),
      body: SafeArea(
        child: Column(
          children: [
            _buildConnectionBar(),
            _buildStatusStrip(state),
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
                      SizedBox(height: 330, child: _buildControls(state)),
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

  Widget _buildConnectionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('map2-rosbridge-url'),
              controller: _urlController,
              enabled: !_isConnected,
              decoration: const InputDecoration(
                labelText: 'ROS WebSocket',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('map2-connect'),
            onPressed: _connectionStatus == RosbridgeConnectionStatus.connecting
                ? null
                : _toggleConnection,
            icon: Icon(_isConnected ? Icons.link_off : Icons.link),
            label: Text(_isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(RoundTripNavigationState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            _connectionStatus.name,
            key: const ValueKey('map2-connection-status'),
          ),
          Text(
            state.phase.label,
            key: const ValueKey('map2-trip-phase'),
          ),
          if (state.message != null) Text(state.message!),
          if (_connectionMessage != null) Text(_connectionMessage!),
        ],
      ),
    );
  }

  Widget _buildMap(RoundTripNavigationState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: _mapInfo.width / _mapInfo.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                key: const ValueKey('map2-map-surface'),
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
                        'Initial',
                      ),
                    if (state.latestPose != null)
                      _buildMarker(
                        state.latestPose!,
                        size,
                        Icons.navigation,
                        Colors.green.shade700,
                        'Robot',
                      ),
                    if (state.home != null)
                      _buildMarker(
                        state.home!,
                        size,
                        Icons.home,
                        Colors.blue.shade700,
                        'Home',
                      ),
                    if (state.target != null)
                      _buildMarker(
                        state.target!,
                        size,
                        Icons.flag,
                        Colors.red.shade700,
                        'Target',
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
    final left = pixel.x / _mapInfo.width * size.width - 15;
    final top = pixel.y / _mapInfo.height * size.height - 15;
    return Positioned(
      left: left,
      top: top,
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

  Widget _buildControls(RoundTripNavigationState state) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<_Map2PoseMode>(
          key: const ValueKey('map2-pose-mode'),
          segments: const [
            ButtonSegment(
              value: _Map2PoseMode.initialPose,
              icon: Icon(Icons.my_location),
              label: Text('Start'),
            ),
            ButtonSegment(
              value: _Map2PoseMode.target,
              icon: Icon(Icons.flag),
              label: Text(
                'Target',
                key: ValueKey('map2-target-mode-label'),
              ),
            ),
          ],
          selected: {_poseMode},
          onSelectionChanged: state.isBusy
              ? null
              : (selection) => setState(() => _poseMode = selection.first),
        ),
        const SizedBox(height: 12),
        Text('Yaw: ${_selectedYaw.toStringAsFixed(2)} rad'),
        Slider(
          key: const ValueKey('map2-yaw'),
          min: -math.pi,
          max: math.pi,
          value: _selectedYaw,
          onChanged: state.isBusy ? null : _setYaw,
        ),
        _PoseSummary(label: 'Initial', pose: _initialPose),
        _PoseSummary(label: 'AMCL', pose: state.latestPose),
        _PoseSummary(label: 'Home', pose: state.home),
        _PoseSummary(label: 'Target', pose: state.target),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('map2-set-start'),
          onPressed: _isConnected && _initialPose != null && !state.isBusy
              ? _publishInitialPose
              : null,
          icon: const Icon(Icons.my_location),
          label: Text(_initialPoseSent ? 'Start sent' : 'Set start'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('map2-capture-home'),
          onPressed:
              _isConnected && !state.isBusy ? _controller.captureHome : null,
          icon: const Icon(Icons.home),
          label: const Text('Capture home from AMCL'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('map2-go'),
          onPressed:
              _isConnected && state.canStartOutbound ? _confirmOutbound : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Go to target'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('map2-stop'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _isConnected && state.canStop ? _controller.stop : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('map2-reset'),
          onPressed: state.isBusy ? null : _controller.resetTrip,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset trip'),
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
