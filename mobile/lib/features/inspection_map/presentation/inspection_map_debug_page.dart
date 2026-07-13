import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/inspection_map_api_repository.dart';
import '../data/inspection_map_mock_repository.dart';
import '../data/inspection_map_repository.dart';
import '../data/robot_control_bridge_client.dart';
import '../models/inspection_marker.dart';
import '../models/inspection_place.dart';
import '../models/inspection_route.dart';
import '../models/map_info.dart';
import '../models/navigation_status.dart';
import '../models/obstacle_status.dart';
import '../utils/coordinate_converter.dart';

enum _ClickMode { initialPose, navGoal }

enum _DataSource { mockAssets, backendApi }

class InspectionMapDebugPage extends StatefulWidget {
  const InspectionMapDebugPage({super.key});

  @override
  State<InspectionMapDebugPage> createState() => _InspectionMapDebugPageState();
}

class _InspectionMapDebugPageState extends State<InspectionMapDebugPage> {
  final _transformController = TransformationController();
  final _robotBridge = RobotControlBridgeClient();

  _DataSource _dataSource = _DataSource.mockAssets;
  InspectionMapRepository _repository = InspectionMapMockRepository();
  late Future<void> _loadFuture;
  MapInfo? _mapInfo;
  List<InspectionMarker> _markers = const [];
  List<InspectionPlace> _places = const [];
  List<InspectionRoute> _routes = const [];
  NavigationStatus? _navigationStatus;
  ObstacleStatus? _obstacleStatus;

  _ClickMode _clickMode = _ClickMode.navGoal;
  PixelPoint? _selectedPixel;
  MapPoint? _selectedMap;
  PixelPoint? _initialPosePixel;
  Map<String, dynamic>? _initialPoseJson;
  Map<String, dynamic>? _navGoalJson;
  List<MapPoint> _realPlanMapPoints = const [];
  List<PixelPoint> _realPlanPixels = const [];
  double _initialPoseYaw = 0;
  bool _initialPoseSent = false;
  String? _errorMessage;
  String? _robotBridgeStatus;
  bool _robotBridgeBusy = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      _repository.loadMapInfo(),
      _repository.loadMarkers(),
      _repository.loadPlaces(),
      _repository.loadRoutes(),
      _repository.loadNavigationStatus(),
      _repository.loadObstacleStatus(),
    ]);
    _mapInfo = results[0] as MapInfo;
    _markers = results[1] as List<InspectionMarker>;
    _places = results[2] as List<InspectionPlace>;
    _routes = results[3] as List<InspectionRoute>;
    _navigationStatus = results[4] as NavigationStatus;
    _obstacleStatus = results[5] as ObstacleStatus;
    _errorMessage = null;
  }

  void _selectDataSource(_DataSource source) {
    setState(() {
      _dataSource = source;
      _repository = source == _DataSource.mockAssets
          ? InspectionMapMockRepository()
          : InspectionMapApiRepository(baseUrl: 'http://localhost:8080/api');
      _errorMessage = null;
      _loadFuture = _load();
    });
  }

  void _refresh() {
    setState(() {
      _errorMessage = null;
      _loadFuture = _load();
    });
  }

  Future<void> _runRepositoryAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _startNavigation() async {
    final target = _resolveNavigationTarget();
    await _runRepositoryAction(() async {
      final status = await _repository.startNavigation(
        targetName: target.name,
        targetX: target.pixelX.round(),
        targetY: target.pixelY.round(),
      );
      _navigationStatus = status;
    });
  }

  Future<void> _cancelNavigation() async {
    await _runRepositoryAction(() async {
      _navigationStatus = await _repository.cancelNavigation();
    });
  }

  Future<void> _returnHome() async {
    await _runRepositoryAction(() async {
      _navigationStatus = await _repository.returnHome();
    });
  }

  Future<void> _sendInitialPoseToCar() async {
    final pose = _initialPoseJson;
    if (pose == null) return;
    final sent = await _runRobotBridgeAction(
      action: () => _robotBridge.publishInitialPose(pose),
      successMessage: 'AMCL initial estimate sent to the real car',
    );
    if (sent && mounted) {
      setState(() => _initialPoseSent = true);
    }
  }

  Future<void> _checkRobotBridge() async {
    await _runRobotBridgeAction(
      action: _robotBridge.checkHealth,
      successMessage: 'Robot bridge is reachable',
    );
  }

  Future<void> _checkNavigationReady() async {
    await _runRobotBridgeAction(
      action: _robotBridge.checkNavigationReady,
      successMessage: 'Robot navigation graph checked',
    );
  }

  Future<void> _restartRobotNavigationStack() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart robot navigation stack?'),
        content: const Text(
          'This stops known n1/n3/Nav2 processes in Docker, then starts n1 '
          'and n3 again. Use it when processes are running but topics are '
          'missing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart stack'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runRobotBridgeAction(
      action: _robotBridge.restartNavigation,
      successMessage: 'Robot navigation stack restarted',
    );
  }

  Future<void> _emergencyStopRobot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop real car now?'),
        content: const Text(
          'This stops Nav2 control and publishes zero velocity to /cmd_vel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runRobotBridgeAction(
      action: _robotBridge.emergencyStop,
      successMessage: 'Emergency stop sent to the real car',
    );
  }

  Future<void> _refreshRealPlan() async {
    await _loadRealPlan(maxAttempts: 1);
  }

  Future<void> _startRobotNavigationStack() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prepare robot navigation?'),
        content: const Text(
          'This runs s, enters Docker (d), then starts n1 (base and laser) '
          'and n3 (DWA navigation). It does not send a goal or move the car.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.power_settings_new),
            label: const Text('Prepare robot'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runRobotBridgeAction(
      action: _robotBridge.prepareNavigation,
      successMessage: 'Robot prepared: s, d, n1 and n3 completed',
    );
  }

  Future<void> _sendGoalPoseToCar() async {
    final pose = _navGoalJson;
    if (pose == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigate real car?'),
        content: Text(
          'This will publish /goal_pose to the real car at '
          'x=${pose['x']}, y=${pose['y']}, yaw=${pose['yaw']}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.navigation),
            label: const Text('Send goal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ready = await _runRobotBridgeAction(
      action: _robotBridge.checkNavigationReady,
      successMessage: 'Robot navigation graph checked',
    );
    if (!ready || !mounted) return;
    final sent = await _runRobotBridgeAction(
      action: () => _robotBridge.publishGoalPose(pose),
      successMessage: 'Goal pose sent to the real car',
    );
    if (sent) {
      await _loadRealPlan(maxAttempts: 2);
    }
  }

  Future<void> _loadRealPlan({required int maxAttempts}) async {
    final mapInfo = _mapInfo;
    if (mapInfo == null) return;
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      final result = await _runRobotBridgeAction(
        action: _robotBridge.loadNavigationPlan,
        successMessage: 'Real navigation plan refreshed',
      );
      if (!result || !mounted) return;
      if (_realPlanPixels.length > 1) return;
    }
  }

  Future<bool> _runRobotBridgeAction({
    required Future<Map<String, dynamic>> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _robotBridgeBusy = true;
      _robotBridgeStatus = null;
    });
    try {
      final result = await action();
      if (!mounted) return false;
      final dryRun = result['dryRun'] == true;
      _applyRobotBridgeResult(result);
      setState(() {
        _robotBridgeStatus = dryRun
            ? '$successMessage (dry-run only)'
            : _formatRobotBridgeStatus(successMessage, result);
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _robotBridgeStatus = 'Robot bridge error: $error';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _robotBridgeBusy = false);
      }
    }
  }

  void _applyRobotBridgeResult(Map<String, dynamic> result) {
    final points = result['points'];
    final mapInfo = _mapInfo;
    if (points is! List || mapInfo == null) return;
    final mapPoints = <MapPoint>[];
    final pixels = <PixelPoint>[];
    for (final point in points) {
      if (point is! Map) continue;
      final x = (point['x'] as num?)?.toDouble();
      final y = (point['y'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      mapPoints.add(MapPoint(x: x, y: y));
      pixels.add(mapToPixel(x, y, mapInfo));
    }
    _realPlanMapPoints = mapPoints;
    _realPlanPixels = pixels;
  }

  String _formatRobotBridgeStatus(
    String successMessage,
    Map<String, dynamic> result,
  ) {
    final ready = result['ready'];
    if (ready == false) {
      final missing = result['missingTopics'];
      return '$successMessage: missing ${missing is List ? missing.join(', ') : 'topics'}';
    }
    final pointCount = result['pointCount'];
    if (pointCount is num) {
      return pointCount > 1
          ? '$successMessage: $pointCount plan points'
          : '$successMessage: no /plan yet';
    }
    return '$successMessage (code=${result['code'] ?? 0})';
  }

  _NavigationTarget _resolveNavigationTarget() {
    final selectedPixel = _selectedPixel;
    if (selectedPixel != null) {
      return _NavigationTarget(
        name: 'selected nav_goal',
        pixelX: selectedPixel.x,
        pixelY: selectedPixel.y,
      );
    }

    for (final place in _places) {
      if (place.id == 'elder_room') {
        return _NavigationTarget(
          name: place.name,
          pixelX: place.pixelX,
          pixelY: place.pixelY,
        );
      }
    }

    InspectionMarker? targetMarker;
    for (final marker in _markers) {
      if (marker.type == InspectionMarkerType.target) {
        targetMarker = marker;
        break;
      }
    }
    if (targetMarker != null) {
      return _NavigationTarget(
        name: targetMarker.title,
        pixelX: targetMarker.pixelX,
        pixelY: targetMarker.pixelY,
      );
    }

    return const _NavigationTarget(name: 'home', pixelX: 90, pixelY: 310);
  }

  void _onMapTap(TapDownDetails details) {
    final mapInfo = _mapInfo;
    if (mapInfo == null) return;
    final local = details.localPosition;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > mapInfo.width ||
        local.dy > mapInfo.height) {
      return;
    }

    final pixel = PixelPoint(x: local.dx, y: local.dy);
    final map = pixelToMap(pixel.x, pixel.y, mapInfo);
    final payload = _posePayload(
      type: _clickMode == _ClickMode.initialPose ? 'initial_pose' : 'nav_goal',
      mapInfo: mapInfo,
      map: map,
      yaw: _clickMode == _ClickMode.initialPose ? _initialPoseYaw : 0,
    );

    setState(() {
      _selectedPixel = pixel;
      _selectedMap = map;
      if (_clickMode == _ClickMode.initialPose) {
        _initialPosePixel = pixel;
        _initialPoseJson = payload;
        _initialPoseSent = false;
      } else {
        _navGoalJson = payload;
      }
    });
  }

  void _selectMarkerAsNavigationTarget(InspectionMarker marker) {
    final mapInfo = _mapInfo;
    if (mapInfo == null) return;

    final pixel = PixelPoint(x: marker.pixelX, y: marker.pixelY);
    final map = pixelToMap(pixel.x, pixel.y, mapInfo);
    final payload = _posePayload(
      type: 'nav_goal',
      mapInfo: mapInfo,
      map: map,
      yaw: 0,
    );

    setState(() {
      _selectedPixel = pixel;
      _selectedMap = map;
      _navGoalJson = payload;
    });
  }

  Map<String, dynamic> _posePayload({
    required String type,
    required MapInfo mapInfo,
    required MapPoint map,
    required double yaw,
  }) {
    return {
      'type': type,
      'frame_id': mapInfo.frameId,
      'x': _round(map.x),
      'y': _round(map.y),
      'yaw': _round(_normalizeYaw(yaw)),
    };
  }

  void _setInitialPoseYaw(double yaw) {
    final pose = _initialPoseJson;
    setState(() {
      _initialPoseYaw = _normalizeYaw(yaw);
      if (pose != null) {
        _initialPoseJson = {
          ...pose,
          'yaw': _round(_initialPoseYaw),
        };
        _initialPoseSent = false;
      }
    });
  }

  double _normalizeYaw(double yaw) {
    var value = yaw;
    while (value > math.pi) {
      value -= math.pi * 2;
    }
    while (value <= -math.pi) {
      value += math.pi * 2;
    }
    return value;
  }

  Future<void> _showMarkerDetail(InspectionMarker marker) async {
    final handled = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marker.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailLine(label: 'type', value: marker.type.name),
              _DetailLine(label: 'status', value: marker.status),
              _DetailLine(
                label: 'pixel',
                value: '${_round(marker.pixelX)}, ${_round(marker.pixelY)}',
              ),
              _DetailLine(
                label: 'map',
                value: '${_round(marker.mapX)}, ${_round(marker.mapY)}',
              ),
              if ((marker.locationName ?? '').isNotEmpty)
                _DetailLine(label: 'location', value: marker.locationName!),
              if (marker.message.isNotEmpty)
                _DetailLine(label: 'message', value: marker.message),
              if (marker.type == InspectionMarkerType.fall) ...[
                const Divider(height: 20),
                _DetailLine(label: 'elderName', value: marker.elderName ?? ''),
                _DetailLine(
                  label: 'identitySource',
                  value: marker.identitySource ?? '',
                ),
                _DetailLine(
                  label: 'identityConfidence',
                  value: '${marker.identityConfidence ?? 0}',
                ),
                _DetailLine(
                  label: 'notifiedChild',
                  value: '${marker.notifiedChild ?? false}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
          if (marker.canHandle)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mark handled'),
            ),
        ],
      ),
    );

    if (handled == true) {
      await _runRepositoryAction(() async {
        await _repository.handleMarker(
          marker.id,
          handler: 'inspection_map_debug',
          remark: 'marked handled from debug page',
        );
        _markers = await _repository.loadMarkers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inspection Map Debug'),
            Text(
              'Isolated debug page, not formal app navigation',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDataSourceBar(context),
          Expanded(
            child: FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildLoadError(snapshot.error);
                }
                return _buildContent(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text('Data source', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            SegmentedButton<_DataSource>(
              segments: const [
                ButtonSegment(
                  value: _DataSource.mockAssets,
                  label: Text('Mock assets'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: _DataSource.backendApi,
                  label: Text('Backend API'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {_dataSource},
              onSelectionChanged: (value) => _selectDataSource(value.first),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            if (_dataSource == _DataSource.backendApi) ...[
              const SizedBox(width: 12),
              const Text('http://localhost:8080/api'),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Inspection map debug load failed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _selectDataSource(_DataSource.mockAssets),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Switch to Mock assets'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final mapInfo = _mapInfo!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xFFE5E7EB),
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.5,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(160),
                    child: Center(
                      child: GestureDetector(
                        onTapDown: _onMapTap,
                        child: SizedBox(
                          width: mapInfo.width.toDouble(),
                          height: mapInfo.height.toDouble(),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  mapInfo.imageAsset,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              if (_realPlanPixels.length > 1)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _PlanPainter(_realPlanPixels),
                                    ),
                                  ),
                                ),
                              ..._markers.map(_buildMarker),
                              if (_initialPosePixel != null)
                                Positioned(
                                  left: _initialPosePixel!.x - 32,
                                  top: _initialPosePixel!.y - 32,
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      size: const Size(64, 64),
                                      painter: _PoseArrowPainter(
                                        yaw: _initialPoseYaw,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_selectedPixel != null)
                                Positioned(
                                  left: _selectedPixel!.x - 7,
                                  top: _selectedPixel!.y - 7,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 8,
                                          color: Colors.black26,
                                        ),
                                      ],
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
              SizedBox(width: 360, child: _buildSidePanel(context)),
            ],
          ),
        ),
        _buildJsonPanel(context),
      ],
    );
  }

  Widget _buildMarker(InspectionMarker marker) {
    final color = _markerColor(marker.type);
    final icon = _markerIcon(marker.type);
    return Positioned(
      left: marker.pixelX - 11,
      top: marker.pixelY - 11,
      child: Tooltip(
        message: '${marker.title}\n${marker.status}',
        child: GestureDetector(
          onTap: () {
            if (_clickMode == _ClickMode.navGoal &&
                marker.type == InspectionMarkerType.target) {
              _selectMarkerAsNavigationTarget(marker);
              return;
            }
            _showMarkerDetail(marker);
          },
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black38),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final mapInfo = _mapInfo!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Map info', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoLine(label: 'image', value: mapInfo.imageFile),
        _InfoLine(label: 'size', value: '${mapInfo.width} x ${mapInfo.height}'),
        _InfoLine(label: 'resolution', value: '${mapInfo.resolution}'),
        _InfoLine(label: 'origin', value: '${mapInfo.origin}'),
        const Divider(height: 28),
        Text('Click mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<_ClickMode>(
          segments: const [
            ButtonSegment(
              value: _ClickMode.initialPose,
              label: Text('Set start'),
              icon: Icon(Icons.flag_outlined),
            ),
            ButtonSegment(
              value: _ClickMode.navGoal,
              label: Text('Set target'),
              icon: Icon(Icons.place_outlined),
            ),
          ],
          selected: {_clickMode},
          onSelectionChanged: (value) {
            setState(() => _clickMode = value.first);
          },
        ),
        const Divider(height: 28),
        Text('Current click', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoLine(
          label: 'pixel',
          value: _selectedPixel == null
              ? '-'
              : '${_round(_selectedPixel!.x)}, ${_round(_selectedPixel!.y)}',
        ),
        _InfoLine(
          label: 'ROS map',
          value: _selectedMap == null
              ? '-'
              : '${_round(_selectedMap!.x)}, ${_round(_selectedMap!.y)}',
        ),
        if (_initialPoseJson != null) ...[
          const SizedBox(height: 12),
          Text(
            'Initial pose heading',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          _InfoLine(
            label: 'yaw',
            value:
                '${_round(_initialPoseYaw)} rad / ${_round(_initialPoseYaw * 180 / math.pi)} deg',
          ),
          Slider(
            min: -math.pi,
            max: math.pi,
            divisions: 72,
            value: _initialPoseYaw,
            onChanged: _setInitialPoseYaw,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _setInitialPoseYaw(0),
                child: const Text('0 deg'),
              ),
              OutlinedButton(
                onPressed: () => _setInitialPoseYaw(math.pi / 2),
                child: const Text('90 deg'),
              ),
              OutlinedButton(
                onPressed: () => _setInitialPoseYaw(math.pi),
                child: const Text('180 deg'),
              ),
              OutlinedButton(
                onPressed: () => _setInitialPoseYaw(-math.pi / 2),
                child: const Text('-90 deg'),
              ),
            ],
          ),
        ],
        const Divider(height: 28),
        Text('Real car bridge', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'http://127.0.0.1:18080',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _robotBridgeBusy ? null : _checkRobotBridge,
              icon: const Icon(Icons.link),
              label: const Text('Check bridge'),
            ),
            OutlinedButton.icon(
              onPressed: _robotBridgeBusy ? null : _startRobotNavigationStack,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Prepare s + d + n1 + n3'),
            ),
            OutlinedButton.icon(
              onPressed: _robotBridgeBusy ? null : _checkNavigationReady,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Check nav ready'),
            ),
            OutlinedButton.icon(
              onPressed: _robotBridgeBusy ? null : _restartRobotNavigationStack,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart nav stack'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: _robotBridgeBusy ? null : _emergencyStopRobot,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop real car'),
            ),
            OutlinedButton.icon(
              onPressed: _initialPoseJson == null || _robotBridgeBusy
                  ? null
                  : _sendInitialPoseToCar,
              icon: const Icon(Icons.my_location),
              label: const Text('Send AMCL initial estimate'),
            ),
            FilledButton.icon(
              onPressed:
                  _navGoalJson == null || !_initialPoseSent || _robotBridgeBusy
                      ? null
                      : _sendGoalPoseToCar,
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate real car'),
            ),
            OutlinedButton.icon(
              onPressed: _robotBridgeBusy ? null : _refreshRealPlan,
              icon: const Icon(Icons.alt_route),
              label: const Text('Refresh real plan'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '/initialpose gives AMCL an initial estimate. Laser-to-map matching '
          'corrects it afterward; it is not automatic localization. Use a map '
          'that matches the real place.',
          style: TextStyle(fontSize: 12),
        ),
        if (_robotBridgeBusy) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        if (_robotBridgeStatus != null) ...[
          const SizedBox(height: 10),
          Text(
            _robotBridgeStatus!,
            style: TextStyle(
              color: _robotBridgeStatus!.startsWith('Robot bridge error')
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        if (_realPlanMapPoints.length > 1) ...[
          const SizedBox(height: 8),
          _InfoLine(
            label: 'real plan',
            value: '${_realPlanMapPoints.length} points from /plan',
          ),
        ],
        const Divider(height: 28),
        Text('Status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoLine(
          label: 'navigation',
          value: _navigationStatus?.status.name ?? '-',
        ),
        if ((_navigationStatus?.currentTargetName ?? '').isNotEmpty)
          _InfoLine(
              label: 'target', value: _navigationStatus!.currentTargetName!),
        if ((_navigationStatus?.message ?? '').isNotEmpty)
          _InfoLine(label: 'message', value: _navigationStatus!.message!),
        _InfoLine(label: 'obstacle', value: _obstacleStatus?.status ?? '-'),
        if ((_obstacleStatus?.message ?? '').isNotEmpty)
          _InfoLine(label: 'obstacleMsg', value: _obstacleStatus!.message!),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _startNavigation,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mock start'),
            ),
            OutlinedButton.icon(
              onPressed: _cancelNavigation,
              icon: const Icon(Icons.stop),
              label: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: _returnHome,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Return home'),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const Divider(height: 28),
        Text('Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoLine(label: 'places', value: '${_places.length}'),
        _InfoLine(label: 'routes', value: '${_routes.length}'),
        _InfoLine(label: 'markers', value: '${_markers.length}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InspectionMarkerType.values
              .map(
                (type) => Chip(
                  avatar: CircleAvatar(backgroundColor: _markerColor(type)),
                  label: Text(type.name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildJsonPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(top: BorderSide(color: Color(0xFF374151))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Generated JSON',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert({
              'pixel': {
                'pixelX':
                    _selectedPixel == null ? null : _round(_selectedPixel!.x),
                'pixelY':
                    _selectedPixel == null ? null : _round(_selectedPixel!.y),
              },
              'map': {
                'mapX': _selectedMap == null ? null : _round(_selectedMap!.x),
                'mapY': _selectedMap == null ? null : _round(_selectedMap!.y),
              },
              'initial_pose': _initialPoseJson,
              'nav_goal': _navGoalJson,
              'real_plan_points': _realPlanMapPoints
                  .map((point) => {
                        'x': _round(point.x),
                        'y': _round(point.y),
                      })
                  .toList(),
            }),
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _markerColor(InspectionMarkerType type) {
    switch (type) {
      case InspectionMarkerType.fall:
        return const Color(0xFFDC2626);
      case InspectionMarkerType.crack:
        return const Color(0xFFEAB308);
      case InspectionMarkerType.robot:
        return const Color(0xFF2563EB);
      case InspectionMarkerType.target:
        return const Color(0xFF16A34A);
      case InspectionMarkerType.obstacle:
        return const Color(0xFFF97316);
    }
  }

  IconData _markerIcon(InspectionMarkerType type) {
    switch (type) {
      case InspectionMarkerType.fall:
        return Icons.personal_injury_outlined;
      case InspectionMarkerType.crack:
        return Icons.warning_amber_outlined;
      case InspectionMarkerType.robot:
        return Icons.smart_toy_outlined;
      case InspectionMarkerType.target:
        return Icons.flag_outlined;
      case InspectionMarkerType.obstacle:
        return Icons.block_outlined;
    }
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(4));
}

class _PlanPainter extends CustomPainter {
  const _PlanPainter(this.points);

  final List<PixelPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final shadow = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas
      ..drawPath(path, shadow)
      ..drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PoseArrowPainter extends CustomPainter {
  const _PoseArrowPainter({
    required this.yaw,
    required this.color,
  });

  final double yaw;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final direction = Offset(math.cos(yaw), -math.sin(yaw));
    final end = center + direction * 26;
    final normal = Offset(-direction.dy, direction.dx);
    final headBase = end - direction * 10;

    final shadow = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(end.dx, end.dy)
      ..moveTo((headBase + normal * 6).dx, (headBase + normal * 6).dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo((headBase - normal * 6).dx, (headBase - normal * 6).dy);

    canvas
      ..drawPath(path, shadow)
      ..drawPath(path, line)
      ..drawCircle(center, 5, Paint()..color = Colors.white)
      ..drawCircle(center, 3, dot);
  }

  @override
  bool shouldRepaint(covariant _PoseArrowPainter oldDelegate) {
    return oldDelegate.yaw != yaw || oldDelegate.color != color;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

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
            width: 96,
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

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
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NavigationTarget {
  const _NavigationTarget({
    required this.name,
    required this.pixelX,
    required this.pixelY,
  });

  final String name;
  final double pixelX;
  final double pixelY;
}
