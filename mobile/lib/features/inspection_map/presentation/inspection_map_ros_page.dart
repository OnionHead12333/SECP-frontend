import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rosbridge_navigation_client.dart';
import '../models/map_info.dart';
import '../models/ros_navigation_models.dart';
import '../utils/coordinate_converter.dart';
import '../utils/occupancy_grid_placement.dart';

enum _PoseMode { initialPose, goalPose }

enum InspectionMapExperience { debug, employee }

enum _EmployeeSection { map, navigation, startup }

class InspectionMapRosPage extends StatefulWidget {
  const InspectionMapRosPage({
    super.key,
    this.initialUrl = const String.fromEnvironment(
      'ROSBRIDGE_URL',
      defaultValue: 'ws://192.168.137.142:9090',
    ),
    this.autoConnect = const bool.fromEnvironment(
      'ROSBRIDGE_AUTO_CONNECT',
      defaultValue: true,
    ),
    this.rosClient,
    this.experience = InspectionMapExperience.debug,
    this.onStartRobotServices,
  });

  final String initialUrl;
  final bool autoConnect;
  final RosbridgeNavigationClient? rosClient;
  final InspectionMapExperience experience;
  final Future<void> Function()? onStartRobotServices;

  @override
  State<InspectionMapRosPage> createState() => _InspectionMapRosPageState();
}

class _InspectionMapRosPageState extends State<InspectionMapRosPage> {
  static const _commandGuardDuration = Duration(milliseconds: 800);
  static const _fallbackMapInfo = MapInfo(
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
  static const _particleSpreadWarningMeters = 1.5;

  final _transformController = TransformationController();
  late final RosbridgeNavigationClient _rosClient;
  final _tfTree = RosTfTree();

  late final TextEditingController _urlController;
  StreamSubscription<RosbridgeConnectionEvent>? _connectionSubscription;
  StreamSubscription<RosbridgeTopicMessage>? _messageSubscription;

  MapInfo _offlineMapInfo = _fallbackMapInfo;
  MapInfo _mapInfo = _fallbackMapInfo;
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
  String? _mapMetadataMessage;
  DateTime? _lastMessageAt;
  double _linearVelocity = 0;
  double _angularVelocity = 0;
  double _selectedYaw = 0;
  _PoseMode _poseMode = _PoseMode.goalPose;
  bool _initialPoseSent = false;
  bool _mapReceived = false;
  bool _amclReceived = false;
  bool _scanReceived = false;
  bool _tfReceived = false;
  bool _particleCloudReceived = false;
  bool _navigateRequestInFlight = false;
  bool _stopRequestInFlight = false;
  bool _startupRequestInFlight = false;
  String? _startupMessage;
  _EmployeeSection _employeeSection = _EmployeeSection.map;
  int _connectionGeneration = 0;

  bool _showLaser = true;
  bool _showGlobalPlan = true;
  bool _showLocalPlan = true;
  bool _showGlobalCostmap = true;
  bool _showLocalCostmap = true;
  bool _showParticles = false;
  bool _showCostCloud = false;

  bool get _isConnected =>
      _connectionStatus == RosbridgeConnectionStatus.connected;

  bool get _scanTfReady {
    final scan = _laserScan;
    if (!_scanReceived || scan == null) return false;
    if (normalizeRosFrame(scan.frameId) ==
        normalizeRosFrame(_mapInfo.frameId)) {
      return true;
    }
    return _tfReceived &&
        _tfTree.resolve(_mapInfo.frameId, scan.frameId) != null;
  }

  double? get _particleSpreadMeters {
    if (!_particleCloudReceived) return null;
    final cloud = _particleCloud;
    if (cloud == null) return null;
    final poses = cloud.poses.map(_poseInMap).whereType<RosPose2D>().toList();
    if (poses.length < 4) return null;

    final meanX =
        poses.fold<double>(0, (sum, pose) => sum + pose.x) / poses.length;
    final meanY =
        poses.fold<double>(0, (sum, pose) => sum + pose.y) / poses.length;
    final radialVariance = poses.fold<double>(0, (sum, pose) {
          final dx = pose.x - meanX;
          final dy = pose.y - meanY;
          return sum + dx * dx + dy * dy;
        }) /
        poses.length;
    return math.sqrt(radialVariance);
  }

  bool get _localizationClearlyDispersed {
    final spread = _particleSpreadMeters;
    return spread != null && spread > _particleSpreadWarningMeters;
  }

  bool get _navigationActionActive => switch (_goalStatus) {
        RosGoalStatus.accepted ||
        RosGoalStatus.executing ||
        RosGoalStatus.canceling =>
          true,
        _ => false,
      };

  List<String> get _navigationBlockers {
    if (!_isConnected) return const ['rosbridge 未连接'];
    final blockers = <String>[
      if (!_mapReceived) '未收到 /map',
      if (!_amclReceived) '未收到 /amcl_pose',
      if (!_scanReceived) '未收到 /scan',
      if (_scanReceived && !_scanTfReady) '等待 /scan 到 map 的 TF',
      if (_localizationClearlyDispersed) '定位未收敛（AMCL 粒子分散）',
      if (_navigationActionActive) '已有导航任务正在执行',
      if (_goalPose == null) '请在 Target 模式点击地图',
    ];
    return blockers;
  }

  @override
  void initState() {
    super.initState();
    _rosClient = widget.rosClient ?? RosbridgeNavigationClient();
    _urlController = TextEditingController(text: widget.initialUrl);
    unawaited(_loadFallbackMapInfo());
    _connectionSubscription =
        _rosClient.connectionEvents.listen(_handleConnectionEvent);
    _messageSubscription = _rosClient.messages.listen(_handleRosMessage);
    if (widget.autoConnect) {
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
    try {
      await _rosClient.connect(_urlController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _connectionMessage = 'Connect failed: $error');
    }
  }

  Future<void> _disconnect() => _rosClient.disconnect();

  Future<void> _loadFallbackMapInfo() async {
    try {
      final source = await rootBundle.loadString(
        'assets/robot_maps/map_info.json',
      );
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException('map_info.json must contain an object');
      }
      final mapInfo = MapInfo.fromJson(Map<String, dynamic>.from(decoded));
      if (mapInfo.width <= 0 ||
          mapInfo.height <= 0 ||
          mapInfo.imageHeight <= 0 ||
          mapInfo.resolution <= 0 ||
          mapInfo.origin.length < 2 ||
          mapInfo.imageAsset.isEmpty) {
        throw const FormatException('map_info.json contains invalid metadata');
      }
      if (!mounted || _mapReceived) return;
      setState(() {
        _offlineMapInfo = mapInfo;
        _mapInfo = mapInfo;
        _mapMetadataMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mapMetadataMessage =
            'Offline map metadata unavailable; using built-in values: $error';
      });
    }
  }

  void _resetSessionReadiness() {
    _connectionGeneration += 1;
    _mapReceived = false;
    _amclReceived = false;
    _scanReceived = false;
    _tfReceived = false;
    _particleCloudReceived = false;
    _initialPoseSent = false;
    _tfTree.clear();
    _mapImage?.dispose();
    _globalCostmapImage?.dispose();
    _localCostmapImage?.dispose();
    _mapImage = null;
    _globalCostmapImage = null;
    _localCostmapImage = null;
    _globalCostmap = null;
    _localCostmap = null;
    _robotPose = null;
    _initialPose = null;
    _goalPose = null;
    _laserScan = null;
    _particleCloud = null;
    _costCloud = null;
    _globalPlan = null;
    _localPlan = null;
    _feedback = null;
    _goalStatus = RosGoalStatus.unknown;
    _linearVelocity = 0;
    _angularVelocity = 0;
    _selectedYaw = 0;
    _lastMessageAt = null;
    _mapInfo = _offlineMapInfo;
  }

  void _handleConnectionEvent(RosbridgeConnectionEvent event) {
    if (!mounted) return;
    setState(() {
      _connectionStatus = event.status;
      _connectionMessage = event.message;
      if (event.status != RosbridgeConnectionStatus.connected) {
        _resetSessionReadiness();
      }
    });
  }

  void _handleRosMessage(RosbridgeTopicMessage event) {
    if (!mounted) return;
    _lastMessageAt = DateTime.now();
    try {
      switch (event.topic) {
        case '/map':
          unawaited(
            _applyMap(
              RosOccupancyGrid.fromMessage(event.message),
              _connectionGeneration,
            ),
          );
        case '/global_costmap/costmap':
          unawaited(
            _applyGlobalCostmap(
              RosOccupancyGrid.fromMessage(event.message),
              _connectionGeneration,
            ),
          );
        case '/local_costmap/costmap':
          unawaited(
            _applyLocalCostmap(
              RosOccupancyGrid.fromMessage(event.message),
              _connectionGeneration,
            ),
          );
        case '/amcl_pose':
          final header = _asMap(event.message['header']);
          final poseWithCovariance = _asMap(event.message['pose']);
          final pose = _asMap(poseWithCovariance['pose']);
          if (pose.isEmpty) {
            throw const FormatException('/amcl_pose is missing pose.pose');
          }
          setState(() {
            _robotPose = RosPose2D.fromPose(
              pose,
              frameId: '${header['frame_id'] ?? 'map'}',
            );
            _amclReceived = true;
          });
        case '/scan':
          final scan = RosLaserScan.fromMessage(event.message);
          setState(() {
            _laserScan = scan;
            _scanReceived = scan.ranges.isNotEmpty;
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
          final cloud = RosPoseArray.fromMessage(event.message);
          setState(() {
            _particleCloud = cloud;
            _particleCloudReceived = cloud.poses.isNotEmpty;
          });
        case '/cost_cloud':
          setState(() {
            _costCloud = RosPointCloud.fromMessage(event.message);
          });
        case '/tf':
        case '/tf_static':
          _tfTree.updateFromMessage(event.message);
          setState(() => _tfReceived = true);
        case '/inspection_map/goal_pose':
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

  Future<void> _applyMap(RosOccupancyGrid grid, int generation) async {
    if (!grid.isValid) return;
    if (!mounted || generation != _connectionGeneration) return;
    final oldImage = _mapImage;
    setState(() {
      _mapImage = null;
      _mapReceived = true;
      _mapInfo = MapInfo(
        mapName: 'ROS /map',
        imageAsset: _offlineMapInfo.imageAsset,
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

    final image = await _occupancyGridImage(grid, isCostmap: false);
    if (!mounted || generation != _connectionGeneration) {
      image.dispose();
      return;
    }
    setState(() => _mapImage = image);
  }

  Future<void> _applyGlobalCostmap(
    RosOccupancyGrid grid,
    int generation,
  ) async {
    if (!grid.isValid) return;
    final image = await _occupancyGridImage(
      grid,
      isCostmap: true,
      tint: const Color(0xFFDC2626),
    );
    if (!mounted || generation != _connectionGeneration) {
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

  Future<void> _applyLocalCostmap(
    RosOccupancyGrid grid,
    int generation,
  ) async {
    if (!grid.isValid) return;
    final image = await _occupancyGridImage(
      grid,
      isCostmap: true,
      tint: const Color(0xFFF59E0B),
    );
    if (!mounted || generation != _connectionGeneration) {
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

  Future<void> _publishGoalPose() async {
    final pose = _goalPose;
    if (pose == null ||
        _navigationBlockers.isNotEmpty ||
        _navigateRequestInFlight ||
        _stopRequestInFlight) {
      return;
    }
    setState(() => _navigateRequestInFlight = true);
    try {
      _rosClient.publishGoalPose(x: pose.x, y: pose.y, yaw: pose.yaw);
      await Future<void>.delayed(_commandGuardDuration);
    } catch (error) {
      if (!mounted) return;
      setState(() => _connectionMessage = 'Navigate failed: $error');
    } finally {
      if (mounted) setState(() => _navigateRequestInFlight = false);
    }
  }

  Future<void> _stopNavigation() async {
    if (!_isConnected || _stopRequestInFlight) return;
    setState(() => _stopRequestInFlight = true);
    try {
      _rosClient.stopNavigation();
      await Future<void>.delayed(_commandGuardDuration);
    } catch (error) {
      if (!mounted) return;
      setState(() => _connectionMessage = 'Stop navigation failed: $error');
    } finally {
      if (mounted) setState(() => _stopRequestInFlight = false);
    }
  }

  Future<void> _startRobotServices() async {
    final start = widget.onStartRobotServices;
    if (start == null || _startupRequestInFlight) return;
    setState(() {
      _startupRequestInFlight = true;
      _startupMessage = null;
    });
    try {
      await start();
      if (!mounted) return;
      setState(() => _startupMessage = '启动请求已提交');
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupMessage = '启动失败：$error');
    } finally {
      if (mounted) setState(() => _startupRequestInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeMode = widget.experience == InspectionMapExperience.employee;
    return Scaffold(
      appBar: AppBar(
        title: Text(employeeMode ? '巡检机器人' : 'Robot navigation'),
        actions: [
          IconButton(
            tooltip: employeeMode ? '复位地图视图' : 'Reset map view',
            onPressed: () => _transformController.value = Matrix4.identity(),
            icon: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          employeeMode ? _buildEmployeeBody(context) : _buildDebugBody(context),
    );
  }

  Widget _buildDebugBody(BuildContext context) {
    return Column(
      children: [
        _buildConnectionBar(context),
        Expanded(child: _buildNavigationWorkspace(context, employee: false)),
      ],
    );
  }

  Widget _buildEmployeeBody(BuildContext context) {
    return Column(
      children: [
        _buildEmployeeConnectionBar(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_EmployeeSection>(
              key: const ValueKey('employee-inspection-sections'),
              segments: const [
                ButtonSegment(
                  value: _EmployeeSection.map,
                  icon: Icon(Icons.map_outlined),
                  label: Text(
                    '地图展示',
                    key: ValueKey('employee-inspection-map-tab'),
                  ),
                ),
                ButtonSegment(
                  value: _EmployeeSection.navigation,
                  icon: Icon(Icons.navigation_outlined),
                  label: Text(
                    '导航控制',
                    key: ValueKey('employee-inspection-navigation-tab'),
                  ),
                ),
                ButtonSegment(
                  value: _EmployeeSection.startup,
                  icon: Icon(Icons.power_settings_new),
                  label: Text(
                    '启动准备',
                    key: ValueKey('employee-inspection-startup-tab'),
                  ),
                ),
              ],
              selected: {_employeeSection},
              onSelectionChanged: (selection) {
                setState(() => _employeeSection = selection.first);
              },
            ),
          ),
        ),
        Expanded(
          child: switch (_employeeSection) {
            _EmployeeSection.map => _buildEmployeeMapView(context),
            _EmployeeSection.navigation =>
              _buildNavigationWorkspace(context, employee: true),
            _EmployeeSection.startup => _buildEmployeeStartupView(context),
          },
        ),
      ],
    );
  }

  Widget _buildNavigationWorkspace(
    BuildContext context, {
    required bool employee,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlPanel = employee
            ? _buildEmployeeNavigationPanel(context)
            : _buildControlPanel(context);
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildMapSurface(
                  context,
                  allowPoseSelection: true,
                ),
              ),
              SizedBox(
                height: math.min(
                  employee ? 360 : 330,
                  constraints.maxHeight * (employee ? 0.5 : 0.42),
                ),
                child: controlPanel,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildMapSurface(
                context,
                allowPoseSelection: true,
              ),
            ),
            SizedBox(width: employee ? 376 : 352, child: controlPanel),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeConnectionBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _connectionStatus == RosbridgeConnectionStatus.connecting ||
        _connectionStatus == RosbridgeConnectionStatus.reconnecting;
    final canConnect = !busy && !_isConnected;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _connectionColor(scheme),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '机器人连接',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    _employeeConnectionLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('employee-inspection-connect'),
              tooltip: '连接机器人',
              onPressed: canConnect ? _connect : null,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeMapView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildMapSurface(
            context,
            allowPoseSelection: false,
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EmployeeSignal(
                  icon: Icons.map_outlined,
                  label: '地图',
                  ready: _mapReceived,
                ),
                _EmployeeSignal(
                  icon: Icons.my_location,
                  label: '定位',
                  ready: _amclReceived,
                ),
                _EmployeeSignal(
                  icon: Icons.radar,
                  label: '雷达',
                  ready: _scanReceived,
                ),
                _EmployeeSignal(
                  icon: Icons.account_tree_outlined,
                  label: '坐标',
                  ready: _scanTfReady,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeStartupView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final startupConfigured = widget.onStartRobotServices != null;
    return ListView(
      key: const ValueKey('employee-inspection-startup-view'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('启动准备', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _InfoRow(label: '机器人连接', value: _employeeConnectionLabel),
        _InfoRow(label: '地图服务', value: _employeeReadyLabel(_mapReceived)),
        _InfoRow(label: '定位服务', value: _employeeReadyLabel(_amclReceived)),
        _InfoRow(label: '雷达数据', value: _employeeReadyLabel(_scanReceived)),
        _InfoRow(label: '坐标变换', value: _employeeReadyLabel(_scanTfReady)),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('employee-inspection-start-services'),
          onPressed: startupConfigured && !_startupRequestInFlight
              ? _startRobotServices
              : null,
          icon: _startupRequestInFlight
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.power_settings_new),
          label: Text(_startupRequestInFlight ? '正在启动' : '一键启动机器人服务'),
        ),
        const SizedBox(height: 8),
        if (!startupConfigured)
          Text(
            '启动服务接口未配置',
            key: const ValueKey('employee-inspection-startup-unconfigured'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        if (_startupMessage != null)
          Text(
            _startupMessage!,
            style: TextStyle(
              color: _startupMessage!.startsWith('启动失败')
                  ? scheme.error
                  : const Color(0xFF166534),
            ),
          ),
        const Divider(height: 32),
        Text('导航状态', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoRow(label: '任务', value: _goalStatus.label),
        _InfoRow(
          label: '速度',
          value: '${_linearVelocity.toStringAsFixed(2)} m/s  '
              '${_angularVelocity.toStringAsFixed(2)} rad/s',
        ),
        _InfoRow(
          label: '最近消息',
          value: _lastMessageAt == null ? '-' : _formatTime(_lastMessageAt!),
        ),
      ],
    );
  }

  Widget _buildEmployeeNavigationPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedPose =
        _poseMode == _PoseMode.initialPose ? _initialPose : _goalPose;
    final navigationBlockers = _navigationBlockers;
    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('导航准备', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: navigationBlockers.isEmpty
                  ? const Color(0xFFDCFCE7)
                  : scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              navigationBlockers.isEmpty
                  ? '导航就绪'
                  : navigationBlockers.join('；'),
              style: TextStyle(
                color: navigationBlockers.isEmpty
                    ? const Color(0xFF166534)
                    : scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_PoseMode>(
            segments: const [
              ButtonSegment(
                value: _PoseMode.initialPose,
                icon: Icon(Icons.my_location),
                label: Text('初始位置'),
              ),
              ButtonSegment(
                value: _PoseMode.goalPose,
                icon: Icon(Icons.flag_outlined),
                label: Text('目标位置'),
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
            label: '位置',
            value: selectedPose == null
                ? '-'
                : '${selectedPose.x.toStringAsFixed(3)}, '
                    '${selectedPose.y.toStringAsFixed(3)}',
          ),
          _InfoRow(
            label: '朝向',
            value: '${(_selectedYaw * 180 / math.pi).toStringAsFixed(1)}°',
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
                  label: const Text('设置初始位置'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('inspection-map-navigate'),
                  onPressed: navigationBlockers.isEmpty &&
                          !_navigateRequestInFlight &&
                          !_stopRequestInFlight
                      ? _publishGoalPose
                      : null,
                  icon: const Icon(Icons.navigation),
                  label: Text(_navigateRequestInFlight ? '正在发送' : '开始导航'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('inspection-map-stop'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed:
                _isConnected && !_stopRequestInFlight ? _stopNavigation : null,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_stopRequestInFlight ? '正在停止' : '停止导航'),
          ),
          const Divider(height: 28),
          Text('任务状态', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoRow(label: '状态', value: _goalStatus.label),
          _InfoRow(
            label: '小车位置',
            value: _robotPose == null
                ? '-'
                : '${_robotPose!.x.toStringAsFixed(3)}, '
                    '${_robotPose!.y.toStringAsFixed(3)}',
          ),
          _InfoRow(
            label: '剩余距离',
            value: _feedback == null
                ? '-'
                : '${_feedback!.distanceRemaining.toStringAsFixed(2)} m',
          ),
          _InfoRow(
            label: '预计时间',
            value: _feedback == null
                ? '-'
                : '${_feedback!.estimatedTimeRemaining.inSeconds} s',
          ),
          if (_connectionMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _connectionMessage!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ],
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

  Widget _buildMapSurface(
    BuildContext context, {
    required bool allowPoseSelection,
  }) {
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
      key: const ValueKey('inspection-map-surface'),
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
                onTapDown: allowPoseSelection ? _onMapTap : null,
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
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(36, 36),
                              painter: _GoalPainter(yaw: _goalPose!.yaw),
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
                                '${_mapInfo.width} x ${_mapInfo.height} '
                                '/ ${_mapInfo.resolution.toStringAsFixed(3)} m/cell',
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
      _mapInfo.imageAsset.isEmpty
          ? _fallbackMapInfo.imageAsset
          : _mapInfo.imageAsset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }

  Widget _buildGridOverlay(RosOccupancyGrid? grid, ui.Image? image) {
    if (grid == null || image == null || !_mapReceived) {
      return const SizedBox.shrink();
    }
    final placement = resolveOccupancyGridPlacement(
      grid: grid,
      mapInfo: _mapInfo,
      tfTree: _tfTree,
    );
    if (placement == null) return const SizedBox.shrink();
    return Positioned(
      left: placement.originPixelX,
      top: placement.originPixelY - placement.height,
      width: placement.width,
      height: placement.height,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: placement.screenRotation,
          alignment: Alignment.bottomLeft,
          child: RawImage(
            image: image,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedPose =
        _poseMode == _PoseMode.initialPose ? _initialPose : _goalPose;
    final navigationBlockers = _navigationBlockers;
    final particleSpread = _particleSpreadMeters;
    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Navigation readiness',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _InfoRow(
              label: 'source', value: _mapReceived ? 'ROS /map' : 'offline'),
          _InfoRow(label: '/map', value: _receivedLabel(_mapReceived)),
          _InfoRow(label: '/amcl_pose', value: _receivedLabel(_amclReceived)),
          _InfoRow(label: '/scan', value: _receivedLabel(_scanReceived)),
          _InfoRow(label: 'scan TF', value: _receivedLabel(_scanTfReady)),
          _InfoRow(
            label: 'map',
            value: '${_mapInfo.width} x ${_mapInfo.height} / '
                '${_mapInfo.resolution.toStringAsFixed(3)} m/cell',
          ),
          _InfoRow(label: 'frame', value: _mapInfo.frameId),
          _InfoRow(
            label: 'origin',
            value: '${_mapInfo.originX.toStringAsFixed(3)}, '
                '${_mapInfo.originY.toStringAsFixed(3)}',
          ),
          if (particleSpread != null)
            _InfoRow(
              label: 'AMCL spread',
              value: '${particleSpread.toStringAsFixed(2)} m',
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: navigationBlockers.isEmpty
                  ? const Color(0xFFDCFCE7)
                  : scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              navigationBlockers.isEmpty
                  ? 'Ready to navigate'
                  : 'Navigate disabled: ${navigationBlockers.join('；')}',
              style: TextStyle(
                color: navigationBlockers.isEmpty
                    ? const Color(0xFF166534)
                    : scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '先用 Start 设置真实初始位置；若雷达点与墙体不重合，请勿导航。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 28),
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
                  key: const ValueKey('inspection-map-navigate'),
                  onPressed: navigationBlockers.isEmpty &&
                          !_navigateRequestInFlight &&
                          !_stopRequestInFlight
                      ? _publishGoalPose
                      : null,
                  icon: const Icon(Icons.navigation),
                  label: Text(
                    _navigateRequestInFlight ? 'Sending...' : 'Navigate',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('inspection-map-stop'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed:
                _isConnected && !_stopRequestInFlight ? _stopNavigation : null,
            icon: const Icon(Icons.stop_circle_outlined),
            label:
                Text(_stopRequestInFlight ? 'Stopping...' : 'Stop navigation'),
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
          if (_mapMetadataMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _mapMetadataMessage!,
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

  String get _employeeConnectionLabel => switch (_connectionStatus) {
        RosbridgeConnectionStatus.disconnected => '未连接',
        RosbridgeConnectionStatus.connecting => '连接中',
        RosbridgeConnectionStatus.connected => '已连接',
        RosbridgeConnectionStatus.reconnecting => '重新连接中',
        RosbridgeConnectionStatus.error => '连接异常',
      };

  String _employeeReadyLabel(bool ready) => ready ? '正常' : '等待数据';

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  String _receivedLabel(bool received) => received ? 'received' : 'waiting';
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
  const _GoalPainter({required this.yaw});

  final double yaw;

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
    final direction = Offset(math.cos(yaw), -math.sin(yaw));
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
          center - const Offset(0, 14), center + const Offset(0, 14), red)
      ..drawLine(center, center + direction * 16, white)
      ..drawLine(center, center + direction * 16, red);
  }

  @override
  bool shouldRepaint(covariant _GoalPainter oldDelegate) =>
      oldDelegate.yaw != yaw;
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

class _EmployeeSignal extends StatelessWidget {
  const _EmployeeSignal({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground =
        ready ? const Color(0xFF166534) : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFDCFCE7) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            '$label ${ready ? '正常' : '等待'}',
            style: TextStyle(color: foreground),
          ),
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
