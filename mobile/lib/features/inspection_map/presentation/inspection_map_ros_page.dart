import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/rosbridge_navigation_client.dart';
import '../models/map_info.dart';
import '../models/ros_navigation_models.dart';
import '../utils/coordinate_converter.dart';

enum _PoseMode { initialPose, goalPose }

class InspectionMapRosPage extends StatefulWidget {
  const InspectionMapRosPage({
    super.key,
    this.initialUrl = const String.fromEnvironment(
      'ROSBRIDGE_URL',
      defaultValue: 'ws://192.168.160.125:9090',
    ),
  });

  final String initialUrl;

  @override
  State<InspectionMapRosPage> createState() => _InspectionMapRosPageState();
}

class _InspectionMapRosPageState extends State<InspectionMapRosPage> {
  static const _fallbackMapInfo = MapInfo(
    mapName: 'yahboomcar',
    imageAsset: 'assets/robot_maps/yahboomcar.png',
    imageFile: 'yahboomcar.png',
    width: 608,
    height: 384,
    imageHeight: 384,
    resolution: 0.05,
    origin: [-10, -10, 0],
    frameId: 'map',
  );

  final _transformController = TransformationController();
  final _rosClient = RosbridgeNavigationClient();
  final _tfTree = RosTfTree();

  late final TextEditingController _urlController;
  StreamSubscription<RosbridgeConnectionEvent>? _connectionSubscription;
  StreamSubscription<RosbridgeTopicMessage>? _messageSubscription;

  MapInfo _mapInfo = _fallbackMapInfo;
  RosOccupancyGrid? _mapGrid;
  RosOccupancyGrid? _globalCostmap;
  RosOccupancyGrid? _localCostmap;
  ui.Image? _mapImage;
  ui.Image? _globalCostmapImage;
  ui.Image? _localCostmapImage;

  RosPose2D? _robotPose;
  RosPose2D? _initialPose;
  RosPose2D? _goalPose;
  RosPath? _globalPlan;
  RosPath? _localPlan;
  RosLaserScan? _laserScan;
  RosPoseArray? _particleCloud;
  RosPointCloud? _costCloud;
  RosNavigationFeedback? _feedback;
  RosGoalStatus _goalStatus = RosGoalStatus.unknown;

  RosbridgeConnectionStatus _connectionStatus =
      RosbridgeConnectionStatus.disconnected;
  String? _connectionMessage;
  DateTime? _lastMessageAt;
  double _linearVelocity = 0;
  double _angularVelocity = 0;
  double _selectedYaw = 0;
  _PoseMode _poseMode = _PoseMode.goalPose;
  bool _initialPoseSent = false;

  bool _showLaser = true;
  bool _showGlobalPlan = true;
  bool _showLocalPlan = true;
  bool _showGlobalCostmap = true;
  bool _showLocalCostmap = true;
  bool _showParticles = false;
  bool _showCostCloud = false;

  bool get _isConnected =>
      _connectionStatus == RosbridgeConnectionStatus.connected;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _connectionSubscription =
        _rosClient.connectionEvents.listen(_handleConnectionEvent);
    _messageSubscription = _rosClient.messages.listen(_handleRosMessage);
    const autoConnect = bool.fromEnvironment(
      'ROSBRIDGE_AUTO_CONNECT',
      defaultValue: true,
    );
    if (autoConnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    unawaited(_rosClient.dispose());
    _urlController.dispose();
    _transformController.dispose();
    _mapImage?.dispose();
    _globalCostmapImage?.dispose();
    _localCostmapImage?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _rosClient.connect(_urlController.text);
  }

  Future<void> _disconnect() => _rosClient.disconnect();

  void _handleConnectionEvent(RosbridgeConnectionEvent event) {
    if (!mounted) return;
    setState(() {
      _connectionStatus = event.status;
      _connectionMessage = event.message;
    });
  }

  void _handleRosMessage(RosbridgeTopicMessage event) {
    if (!mounted) return;
    _lastMessageAt = DateTime.now();
    try {
      switch (event.topic) {
        case '/map':
          unawaited(_applyMap(RosOccupancyGrid.fromMessage(event.message)));
        case '/global_costmap/costmap':
          unawaited(_applyGlobalCostmap(
            RosOccupancyGrid.fromMessage(event.message),
          ));
        case '/local_costmap/costmap':
          unawaited(_applyLocalCostmap(
            RosOccupancyGrid.fromMessage(event.message),
          ));
        case '/amcl_pose':
          final header = _asMap(event.message['header']);
          final poseWithCovariance = _asMap(event.message['pose']);
          final pose = _asMap(poseWithCovariance['pose']);
          setState(() {
            _robotPose = RosPose2D.fromPose(
              pose,
              frameId: '${header['frame_id'] ?? 'map'}',
            );
          });
        case '/scan':
          setState(() {
            _laserScan = RosLaserScan.fromMessage(event.message);
          });
        case '/plan':
          setState(() {
            _globalPlan = RosPath.fromMessage(event.message);
          });
        case '/local_plan':
          setState(() {
            _localPlan = RosPath.fromMessage(event.message);
          });
        case '/particlecloud':
          setState(() {
            _particleCloud = RosPoseArray.fromMessage(event.message);
          });
        case '/cost_cloud':
          setState(() {
            _costCloud = RosPointCloud.fromMessage(event.message);
          });
        case '/tf':
        case '/tf_static':
          _tfTree.updateFromMessage(event.message);
          if (_laserScan != null && mounted) setState(() {});
        case '/goal_pose':
          final header = _asMap(event.message['header']);
          setState(() {
            _goalPose = RosPose2D.fromPose(
              _asMap(event.message['pose']),
              frameId: '${header['frame_id'] ?? 'map'}',
            );
          });
        case '/navigate_to_pose/_action/status':
          setState(() {
            _goalStatus = parseGoalStatus(event.message);
          });
        case '/navigate_to_pose/_action/feedback':
          final feedback = RosNavigationFeedback.fromMessage(event.message);
          setState(() {
            _feedback = feedback;
            _robotPose ??= feedback.currentPose;
          });
        case '/cmd_vel':
          final linear = _asMap(event.message['linear']);
          final angular = _asMap(event.message['angular']);
          setState(() {
            _linearVelocity = _asDouble(linear['x']);
            _angularVelocity = _asDouble(angular['z']);
          });
      }
    } catch (error) {
      setState(() => _connectionMessage = '${event.topic}: $error');
    }
  }

  Future<void> _applyMap(RosOccupancyGrid grid) async {
    if (!grid.isValid) return;
    final image = await _occupancyGridImage(grid, isCostmap: false);
    if (!mounted) {
      image.dispose();
      return;
    }
    final oldImage = _mapImage;
    setState(() {
      _mapGrid = grid;
      _mapImage = image;
      _mapInfo = MapInfo(
        mapName: 'ROS /map',
        imageAsset: _fallbackMapInfo.imageAsset,
        imageFile: '/map',
        width: grid.width,
        height: grid.height,
        imageHeight: grid.height,
        resolution: grid.resolution,
        origin: [grid.origin.x, grid.origin.y, grid.origin.yaw],
        frameId: grid.frameId,
      );
    });
    oldImage?.dispose();
  }

  Future<void> _applyGlobalCostmap(RosOccupancyGrid grid) async {
    if (!grid.isValid) return;
    final image = await _occupancyGridImage(
      grid,
      isCostmap: true,
      tint: const Color(0xFFDC2626),
    );
    if (!mounted) {
      image.dispose();
      return;
    }
    final oldImage = _globalCostmapImage;
    setState(() {
      _globalCostmap = grid;
      _globalCostmapImage = image;
    });
    oldImage?.dispose();
  }

  Future<void> _applyLocalCostmap(RosOccupancyGrid grid) async {
    if (!grid.isValid) return;
    final image = await _occupancyGridImage(
      grid,
      isCostmap: true,
      tint: const Color(0xFFF59E0B),
    );
    if (!mounted) {
      image.dispose();
      return;
    }
    final oldImage = _localCostmapImage;
    setState(() {
      _localCostmap = grid;
      _localCostmapImage = image;
    });
    oldImage?.dispose();
  }

  void _onMapTap(TapDownDetails details) {
    final point = details.localPosition;
    if (point.dx < 0 ||
        point.dy < 0 ||
        point.dx > _mapInfo.width ||
        point.dy > _mapInfo.height) {
      return;
    }
    final mapPoint = pixelToMap(point.dx, point.dy, _mapInfo);
    final pose = RosPose2D(
      x: mapPoint.x,
      y: mapPoint.y,
      yaw: _selectedYaw,
      frameId: _mapInfo.frameId,
    );
    setState(() {
      if (_poseMode == _PoseMode.initialPose) {
        _initialPose = pose;
        _initialPoseSent = false;
      } else {
        _goalPose = pose;
      }
    });
  }

  void _setSelectedYaw(double yaw) {
    final normalized = normalizeYaw(yaw);
    setState(() {
      _selectedYaw = normalized;
      if (_poseMode == _PoseMode.initialPose && _initialPose != null) {
        _initialPose = RosPose2D(
          x: _initialPose!.x,
          y: _initialPose!.y,
          yaw: normalized,
          frameId: _initialPose!.frameId,
        );
        _initialPoseSent = false;
      }
      if (_poseMode == _PoseMode.goalPose && _goalPose != null) {
        _goalPose = RosPose2D(
          x: _goalPose!.x,
          y: _goalPose!.y,
          yaw: normalized,
          frameId: _goalPose!.frameId,
        );
      }
    });
  }

  void _publishInitialPose() {
    final pose = _initialPose;
    if (!_isConnected || pose == null) return;
    _rosClient.publishInitialPose(x: pose.x, y: pose.y, yaw: pose.yaw);
    setState(() => _initialPoseSent = true);
  }

  void _publishGoalPose() {
    final pose = _goalPose;
    if (!_isConnected || pose == null) return;
    _rosClient.publishGoalPose(x: pose.x, y: pose.y, yaw: pose.yaw);
  }

  Future<void> _stopRobot() async {
    if (!_isConnected) return;
    await _rosClient.cancelNavigationAndStop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot navigation'),
        actions: [
          IconButton(
            tooltip: 'Reset map view',
            onPressed: () => _transformController.value = Matrix4.identity(),
            icon: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionBar(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      Expanded(flex: 3, child: _buildMapSurface(context)),
                      SizedBox(
                        height: math.min(330, constraints.maxHeight * 0.42),
                        child: _buildControlPanel(context),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildMapSurface(context)),
                    SizedBox(width: 352, child: _buildControlPanel(context)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _connectionStatus == RosbridgeConnectionStatus.connecting ||
        _connectionStatus == RosbridgeConnectionStatus.reconnecting;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                onSubmitted: (_) => _connect(),
                decoration: const InputDecoration(
                  labelText: 'ROS WebSocket',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cable),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Connect',
              onPressed: busy ? null : _connect,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Disconnect',
              onPressed:
                  _connectionStatus == RosbridgeConnectionStatus.disconnected
                      ? null
                      : _disconnect,
              icon: const Icon(Icons.link_off),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _connectionColor(scheme),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(_connectionLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSurface(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final globalPlan =
        _showGlobalPlan ? _pathPixels(_globalPlan) : const <Offset>[];
    final localPlan =
        _showLocalPlan ? _pathPixels(_localPlan) : const <Offset>[];
    final laserPoints = _showLaser ? _laserPixels() : const <Offset>[];
    final particlePoints =
        _showParticles ? _particlePixels() : const <Offset>[];
    final costCloudPoints =
        _showCostCloud ? _costCloudPixels() : const <Offset>[];
    final robotPose = _poseInMap(_robotPose ?? _feedback?.currentPose);
    final robotPixel = robotPose == null
        ? null
        : mapToPixel(robotPose.x, robotPose.y, _mapInfo);
    final startPixel = _initialPose == null
        ? null
        : mapToPixel(_initialPose!.x, _initialPose!.y, _mapInfo);
    final goalPixel = _goalPose == null
        ? null
        : mapToPixel(_goalPose!.x, _goalPose!.y, _mapInfo);
    final displayScale = math.max(
      1.0,
      math.min(
        560 / _mapInfo.width,
        360 / _mapInfo.height,
      ),
    );

    return ColoredBox(
      color: const Color(0xFFD7DCDD),
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.35,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(180),
        child: Center(
          child: SizedBox(
            width: _mapInfo.width * displayScale,
            height: _mapInfo.height * displayScale,
            child: FittedBox(
              fit: BoxFit.fill,
              child: GestureDetector(
                onTapDown: _onMapTap,
                child: SizedBox(
                  width: _mapInfo.width.toDouble(),
                  height: _mapInfo.height.toDouble(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _buildMapImage()),
                      if (_showGlobalCostmap)
                        _buildGridOverlay(_globalCostmap, _globalCostmapImage),
                      if (_showLocalCostmap)
                        _buildGridOverlay(_localCostmap, _localCostmapImage),
                      if (particlePoints.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PointLayerPainter(
                                particlePoints,
                                color: const Color(0xFF16A34A),
                                radius: 1.5,
                              ),
                            ),
                          ),
                        ),
                      if (costCloudPoints.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PointLayerPainter(
                                costCloudPoints,
                                color: const Color(0xFFE11D48),
                                radius: 1.8,
                              ),
                            ),
                          ),
                        ),
                      if (globalPlan.length > 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PathLayerPainter(
                                globalPlan,
                                color: const Color(0xFF16A34A),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      if (localPlan.length > 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PathLayerPainter(
                                localPlan,
                                color: const Color(0xFF06B6D4),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      if (laserPoints.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PointLayerPainter(
                                laserPoints,
                                color: const Color(0xFFF97316),
                                radius: 1.4,
                              ),
                            ),
                          ),
                        ),
                      if (startPixel != null)
                        Positioned(
                          left: startPixel.x - 28,
                          top: startPixel.y - 28,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(56, 56),
                              painter: _PoseArrowPainter(
                                yaw: _initialPose!.yaw,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      if (goalPixel != null)
                        Positioned(
                          left: goalPixel.x - 18,
                          top: goalPixel.y - 18,
                          child: const IgnorePointer(
                            child: CustomPaint(
                              size: Size(36, 36),
                              painter: _GoalPainter(),
                            ),
                          ),
                        ),
                      if (robotPixel != null)
                        Positioned(
                          left: robotPixel.x - 30,
                          top: robotPixel.y - 30,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(60, 60),
                              painter: _RobotPainter(
                                yaw: robotPose!.yaw,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.64),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: Text(
                                '${_mapInfo.width} x ${_mapInfo.height}  '
                                '${_mapInfo.resolution.toStringAsFixed(3)} m/cell',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapImage() {
    final image = _mapImage;
    if (image != null) {
      return RawImage(
        image: image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      );
    }
    return Image.asset(
      _fallbackMapInfo.imageAsset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }

  Widget _buildGridOverlay(RosOccupancyGrid? grid, ui.Image? image) {
    if (grid == null || image == null || _mapGrid == null) {
      return const SizedBox.shrink();
    }
    final topLeft = mapToPixel(
      grid.origin.x,
      grid.origin.y + grid.height * grid.resolution,
      _mapInfo,
    );
    final width = grid.width * grid.resolution / _mapInfo.resolution;
    final height = grid.height * grid.resolution / _mapInfo.resolution;
    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: width,
      height: height,
      child: IgnorePointer(
        child: RawImage(
          image: image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedPose =
        _poseMode == _PoseMode.initialPose ? _initialPose : _goalPose;
    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pose tool', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<_PoseMode>(
            segments: const [
              ButtonSegment(
                value: _PoseMode.initialPose,
                icon: Icon(Icons.my_location),
                label: Text('Start'),
              ),
              ButtonSegment(
                value: _PoseMode.goalPose,
                icon: Icon(Icons.flag_outlined),
                label: Text('Target'),
              ),
            ],
            selected: {_poseMode},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              setState(() {
                _poseMode = mode;
                final pose =
                    mode == _PoseMode.initialPose ? _initialPose : _goalPose;
                _selectedYaw = pose?.yaw ?? 0;
              });
            },
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'position',
            value: selectedPose == null
                ? '-'
                : '${selectedPose.x.toStringAsFixed(3)}, '
                    '${selectedPose.y.toStringAsFixed(3)}',
          ),
          _InfoRow(
            label: 'yaw',
            value: '${(_selectedYaw * 180 / math.pi).toStringAsFixed(1)} deg',
          ),
          Slider(
            min: -math.pi,
            max: math.pi,
            divisions: 72,
            value: _selectedYaw,
            onChanged: _setSelectedYaw,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isConnected && _initialPose != null
                      ? _publishInitialPose
                      : null,
                  icon: Icon(
                    _initialPoseSent ? Icons.check : Icons.my_location,
                  ),
                  label: const Text('Set start'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isConnected && _goalPose != null
                      ? _publishGoalPose
                      : null,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: _isConnected ? _stopRobot : null,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop robot'),
          ),
          const Divider(height: 28),
          Text('Navigation', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoRow(label: 'state', value: _goalStatus.label),
          _InfoRow(
            label: 'robot',
            value: _robotPose == null
                ? '-'
                : '${_robotPose!.x.toStringAsFixed(3)}, '
                    '${_robotPose!.y.toStringAsFixed(3)}',
          ),
          _InfoRow(
            label: 'velocity',
            value: '${_linearVelocity.toStringAsFixed(2)} m/s  '
                '${_angularVelocity.toStringAsFixed(2)} rad/s',
          ),
          _InfoRow(
            label: 'remaining',
            value: _feedback == null
                ? '-'
                : '${_feedback!.distanceRemaining.toStringAsFixed(2)} m',
          ),
          _InfoRow(
            label: 'ETA',
            value: _feedback == null
                ? '-'
                : '${_feedback!.estimatedTimeRemaining.inSeconds} s',
          ),
          _InfoRow(
            label: 'recoveries',
            value: '${_feedback?.numberOfRecoveries ?? 0}',
          ),
          const Divider(height: 28),
          Text('Layers', style: Theme.of(context).textTheme.titleMedium),
          _LayerToggle(
            label: 'Laser scan',
            color: const Color(0xFFF97316),
            value: _showLaser,
            onChanged: (value) => setState(() => _showLaser = value),
          ),
          _LayerToggle(
            label: 'Global plan',
            color: const Color(0xFF16A34A),
            value: _showGlobalPlan,
            onChanged: (value) => setState(() => _showGlobalPlan = value),
          ),
          _LayerToggle(
            label: 'Local plan',
            color: const Color(0xFF06B6D4),
            value: _showLocalPlan,
            onChanged: (value) => setState(() => _showLocalPlan = value),
          ),
          _LayerToggle(
            label: 'Global costmap',
            color: const Color(0xFFDC2626),
            value: _showGlobalCostmap,
            onChanged: (value) => setState(() => _showGlobalCostmap = value),
          ),
          _LayerToggle(
            label: 'Local costmap',
            color: const Color(0xFFF59E0B),
            value: _showLocalCostmap,
            onChanged: (value) => setState(() => _showLocalCostmap = value),
          ),
          _LayerToggle(
            label: 'AMCL particles',
            color: const Color(0xFF16A34A),
            value: _showParticles,
            onChanged: (value) => setState(() => _showParticles = value),
          ),
          _LayerToggle(
            label: 'Cost cloud',
            color: const Color(0xFFE11D48),
            value: _showCostCloud,
            onChanged: (value) => setState(() => _showCostCloud = value),
          ),
          if (_connectionMessage != null) ...[
            const Divider(height: 28),
            Text(
              _connectionMessage!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ],
          if (_lastMessageAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last ROS message: ${_formatTime(_lastMessageAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Offset> _pathPixels(RosPath? path) {
    if (path == null) return const [];
    return path.poses
        .map(_poseInMap)
        .whereType<RosPose2D>()
        .map((pose) => mapToPixel(pose.x, pose.y, _mapInfo))
        .map((point) => Offset(point.x, point.y))
        .toList(growable: false);
  }

  List<Offset> _laserPixels() {
    final scan = _laserScan;
    if (scan == null || scan.ranges.isEmpty) return const [];
    final transform = _tfTree.resolve(_mapInfo.frameId, scan.frameId);
    if (transform == null) return const [];
    final points = <Offset>[];
    for (var index = 0; index < scan.ranges.length; index += 2) {
      final range = scan.ranges[index];
      if (!range.isFinite || range < scan.rangeMin || range > scan.rangeMax) {
        continue;
      }
      final angle = scan.angleMin + scan.angleIncrement * index;
      final mapPoint = transform.transformPoint(
        RosPoint2D(range * math.cos(angle), range * math.sin(angle)),
      );
      final pixel = mapToPixel(mapPoint.x, mapPoint.y, _mapInfo);
      points.add(Offset(pixel.x, pixel.y));
    }
    return points;
  }

  List<Offset> _particlePixels() {
    final cloud = _particleCloud;
    if (cloud == null) return const [];
    return cloud.poses
        .map(_poseInMap)
        .whereType<RosPose2D>()
        .map((pose) => mapToPixel(pose.x, pose.y, _mapInfo))
        .map((point) => Offset(point.x, point.y))
        .toList(growable: false);
  }

  List<Offset> _costCloudPixels() {
    final cloud = _costCloud;
    if (cloud == null) return const [];
    final transform = _tfTree.resolve(_mapInfo.frameId, cloud.frameId);
    if (transform == null &&
        normalizeRosFrame(cloud.frameId) !=
            normalizeRosFrame(_mapInfo.frameId)) {
      return const [];
    }
    return cloud.points.map((point) {
      final mapPoint = transform?.transformPoint(point) ?? point;
      final pixel = mapToPixel(mapPoint.x, mapPoint.y, _mapInfo);
      return Offset(pixel.x, pixel.y);
    }).toList(growable: false);
  }

  RosPose2D? _poseInMap(RosPose2D? pose) {
    if (pose == null) return null;
    if (normalizeRosFrame(pose.frameId) ==
        normalizeRosFrame(_mapInfo.frameId)) {
      return pose;
    }
    final transform = _tfTree.resolve(_mapInfo.frameId, pose.frameId);
    if (transform == null) return null;
    final point = transform.transformPoint(RosPoint2D(pose.x, pose.y));
    return RosPose2D(
      x: point.x,
      y: point.y,
      yaw: normalizeYaw(transform.yaw + pose.yaw),
      frameId: _mapInfo.frameId,
    );
  }

  Color _connectionColor(ColorScheme scheme) {
    return switch (_connectionStatus) {
      RosbridgeConnectionStatus.connected => const Color(0xFF16A34A),
      RosbridgeConnectionStatus.connecting ||
      RosbridgeConnectionStatus.reconnecting =>
        const Color(0xFFF59E0B),
      RosbridgeConnectionStatus.error => scheme.error,
      RosbridgeConnectionStatus.disconnected => scheme.outline,
    };
  }

  String get _connectionLabel => switch (_connectionStatus) {
        RosbridgeConnectionStatus.disconnected => 'Disconnected',
        RosbridgeConnectionStatus.connecting => 'Connecting',
        RosbridgeConnectionStatus.connected => 'Connected',
        RosbridgeConnectionStatus.reconnecting => 'Reconnecting',
        RosbridgeConnectionStatus.error => 'Connection error',
      };

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}

Future<ui.Image> _occupancyGridImage(
  RosOccupancyGrid grid, {
  required bool isCostmap,
  Color tint = Colors.red,
}) {
  final completer = Completer<ui.Image>();
  final pixels = Uint8List(grid.width * grid.height * 4);
  for (var sourceY = 0; sourceY < grid.height; sourceY += 1) {
    final targetY = grid.height - sourceY - 1;
    for (var x = 0; x < grid.width; x += 1) {
      final sourceIndex = sourceY * grid.width + x;
      final targetIndex = (targetY * grid.width + x) * 4;
      final value = grid.data[sourceIndex];
      if (isCostmap) {
        if (value <= 0) {
          pixels[targetIndex + 3] = 0;
          continue;
        }
        final strength = value.clamp(0, 100) / 100;
        pixels[targetIndex] = (tint.r * 255).round().clamp(0, 255);
        pixels[targetIndex + 1] = (tint.g * 255).round().clamp(0, 255);
        pixels[targetIndex + 2] = (tint.b * 255).round().clamp(0, 255);
        pixels[targetIndex + 3] = (35 + strength * 145).round();
        continue;
      }

      final shade = switch (value) {
        < 0 => 211,
        >= 65 => 32,
        <= 10 => 249,
        _ => (249 - value * 1.9).round().clamp(48, 235),
      };
      pixels[targetIndex] = shade;
      pixels[targetIndex + 1] = shade;
      pixels[targetIndex + 2] = shade;
      pixels[targetIndex + 3] = 255;
    }
  }
  ui.decodeImageFromPixels(
    pixels,
    grid.width,
    grid.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class _PathLayerPainter extends CustomPainter {
  const _PathLayerPainter(
    this.points, {
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final halo = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = width + 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas
      ..drawPath(path, halo)
      ..drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _PathLayerPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}

class _PointLayerPainter extends CustomPainter {
  const _PointLayerPainter(
    this.points, {
    required this.color,
    required this.radius,
  });

  final List<Offset> points;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PointLayerPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;
}

class _PoseArrowPainter extends CustomPainter {
  const _PoseArrowPainter({required this.yaw, required this.color});

  final double yaw;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final direction = Offset(math.cos(yaw), -math.sin(yaw));
    final end = center + direction * 22;
    final normal = Offset(-direction.dy, direction.dx);
    final head = end - direction * 9;
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(end.dx, end.dy)
      ..moveTo((head + normal * 5).dx, (head + normal * 5).dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo((head - normal * 5).dx, (head - normal * 5).dy);
    final halo = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas
      ..drawPath(path, halo)
      ..drawPath(path, line)
      ..drawCircle(center, 4.5, Paint()..color = Colors.white)
      ..drawCircle(center, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PoseArrowPainter oldDelegate) =>
      oldDelegate.yaw != yaw || oldDelegate.color != color;
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter({required this.yaw, required this.color});

  final double yaw;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-yaw);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -9, 24, 18),
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(body.inflate(2), Paint()..color = Colors.white)
      ..drawRRect(body, Paint()..color = color)
      ..drawPath(
        Path()
          ..moveTo(15, 0)
          ..lineTo(7, -6)
          ..lineTo(7, 6)
          ..close(),
        Paint()..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) =>
      oldDelegate.yaw != yaw || oldDelegate.color != color;
}

class _GoalPainter extends CustomPainter {
  const _GoalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final red = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas
      ..drawCircle(center, 10, white)
      ..drawCircle(center, 10, red)
      ..drawLine(
          center - const Offset(14, 0), center + const Offset(14, 0), white)
      ..drawLine(
          center - const Offset(14, 0), center + const Offset(14, 0), red)
      ..drawLine(
          center - const Offset(0, 14), center + const Offset(0, 14), white)
      ..drawLine(
          center - const Offset(0, 14), center + const Offset(0, 14), red);
  }

  @override
  bool shouldRepaint(covariant _GoalPainter oldDelegate) => false;
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label),
      value: value,
      onChanged: (next) => onChanged(next ?? false),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
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

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}
