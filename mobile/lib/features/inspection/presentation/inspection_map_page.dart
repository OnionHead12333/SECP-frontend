import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/inspection_service.dart';
import '../models/inspection_marker.dart';
import 'inspection_marker_detail_sheet.dart';

class InspectionMapPage extends StatefulWidget {
  const InspectionMapPage({super.key});

  @override
  State<InspectionMapPage> createState() => _InspectionMapPageState();
}

class _InspectionMapPageState extends State<InspectionMapPage> {
  late Future<_MapState> _future;
  int? _activeNavigationTaskId;
  InspectionNavigationTask? _localNavigationTask;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MapState> _load() async {
    final mapInfo = await InspectionService.getMapInfo();
    final markers = await InspectionService.getMarkers();
    final navigationStatus = await InspectionService.getNavigationStatus();
    return _MapState(
      mapInfo: mapInfo,
      markers: markers,
      navigationStatus: _mergeLocalNavigationTask(navigationStatus),
    );
  }

  InspectionNavigationStatus? _mergeLocalNavigationTask(
    InspectionNavigationStatus? remoteStatus,
  ) {
    final localTask = _localNavigationTask;
    if (localTask == null) return remoteStatus;

    return InspectionNavigationStatus(
      taskId: remoteStatus?.taskId ?? localTask.id,
      navigationStatus: remoteStatus?.navigationStatus ?? localTask.status,
      obstacleStatus: remoteStatus?.obstacleStatus,
      robotX: remoteStatus?.robotX,
      robotY: remoteStatus?.robotY,
      targetX: localTask.targetX,
      targetY: localTask.targetY,
      targetName: localTask.targetName,
      message: remoteStatus?.message,
      description: remoteStatus?.description,
    );
  }

  void _replaceMarker(InspectionMarker marker) {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _setNavigationTarget(Offset point) async {
    final targetX = point.dx.clamp(0, double.infinity).toDouble();
    final targetY = point.dy.clamp(0, double.infinity).toDouble();
    final targetName =
        'map target ${targetX.toStringAsFixed(0)},${targetY.toStringAsFixed(0)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设为导航目标？'),
        content: Text(
          '目标坐标：${targetX.toStringAsFixed(0)}, ${targetY.toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final task = await InspectionService.createNavigationTask(
      targetName: targetName,
      targetX: targetX,
      targetY: targetY,
    );
    if (!mounted) return;
    _activeNavigationTaskId = task.id;
    _localNavigationTask = task;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _cancelNavigation(int taskId) async {
    await InspectionService.cancelNavigationTask(taskId);
    if (!mounted) return;
    _activeNavigationTaskId = null;
    _localNavigationTask = null;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showDetail(InspectionMarker marker) async {
    final detail = await InspectionService.getMarkerDetail(marker.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InspectionMarkerDetailSheet(
        marker: detail,
        onHandled: _replaceMarker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('巡检地图'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => setState(() {
              _future = _load();
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_MapState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '巡检地图加载失败：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: Text('暂无巡检地图数据'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(state.mapInfo.title,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _MapCanvas(
                mapInfo: state.mapInfo,
                markers: state.markers,
                navigationStatus: state.navigationStatus,
                onTapMarker: _showDetail,
                onTapMap: _setNavigationTarget,
              ),
              if (state.navigationStatus != null) ...[
                const SizedBox(height: 12),
                _NavigationStatusPanel(status: state.navigationStatus!),
                if ((state.navigationStatus!.taskId ??
                        _activeNavigationTaskId) !=
                    null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => _cancelNavigation(
                          state.navigationStatus!.taskId ??
                              _activeNavigationTaskId!),
                      child: const Text('取消导航'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _LegendDot(color: Colors.red, label: '跌倒'),
                  _LegendDot(color: Color(0xFF991B1B), label: 'SOS'),
                  _LegendDot(color: Colors.amber, label: '裂缝'),
                  _LegendDot(color: Colors.blue, label: '小车'),
                  _LegendDot(color: Colors.green, label: '目标'),
                  _LegendDot(color: Colors.orange, label: '障碍物'),
                  _LegendDot(color: Colors.grey, label: '已处理'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.mapInfo,
    required this.markers,
    required this.navigationStatus,
    required this.onTapMarker,
    required this.onTapMap,
  });

  final InspectionMapInfo mapInfo;
  final List<InspectionMarker> markers;
  final InspectionNavigationStatus? navigationStatus;
  final ValueChanged<InspectionMarker> onTapMarker;
  final ValueChanged<Offset> onTapMap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / mapInfo.width,
          520 / mapInfo.height,
        );
        final width = mapInfo.width * scale;
        final height = mapInfo.height * scale;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              key: const ValueKey('inspection-map-canvas'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => onTapMap(
                Offset(
                  details.localPosition.dx / scale,
                  details.localPosition.dy / scale,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _MapBackground(mapInfo: mapInfo)),
                      for (final marker in _markersForDisplay())
                        Positioned(
                          left: marker.x * scale - 14,
                          top: marker.y * scale - 14,
                          child: Opacity(
                            key: ValueKey('marker-opacity-${marker.id}'),
                            opacity:
                                marker.status == InspectionMarkerStatus.handled
                                    ? 0.42
                                    : 1,
                            child: Tooltip(
                              message: marker.title,
                              child: InkWell(
                                key: ValueKey(
                                    'marker-${marker.type}-${marker.id}'),
                                borderRadius: BorderRadius.circular(18),
                                onTap: marker.id < 0
                                    ? null
                                    : () => onTapMarker(marker),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _markerColor(marker),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        blurRadius: 6,
                                        color: Color(0x33000000),
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _markerIcon(marker),
                                    color: Colors.white,
                                    size: 16,
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
        );
      },
    );
  }

  List<InspectionMarker> _markersForDisplay() {
    final status = navigationStatus;
    if (status == null) return markers;

    final hasNavigationTarget =
        status.targetX != null && status.targetY != null;
    final result = [
      for (final marker in markers)
        if (!(hasNavigationTarget && marker.type == 'target')) marker,
    ];
    final hasRobot = result.any((marker) => marker.type == 'robot');
    if (!hasRobot && status.robotX != null && status.robotY != null) {
      result.add(
        InspectionMarker(
          id: -100,
          type: 'robot',
          title: '小车当前位置',
          x: status.robotX!,
          y: status.robotY!,
          level: 'info',
          status: InspectionMarkerStatus.active,
          navigationStatus: status.navigationStatus,
          obstacleStatus: status.obstacleStatus,
        ),
      );
    }

    if (hasNavigationTarget) {
      result.add(
        InspectionMarker(
          id: _navigationTargetMarkerId(status.taskId),
          type: 'target',
          title:
              status.targetName == null ? '导航目标点' : '导航目标：${status.targetName}',
          x: status.targetX!,
          y: status.targetY!,
          level: 'info',
          status: InspectionMarkerStatus.active,
          locationName: status.targetName,
        ),
      );
    }
    return result;
  }

  static int _navigationTargetMarkerId(int? taskId) {
    if (taskId == null || taskId == 0) return -101;
    return -taskId.abs();
  }

  static Color _markerColor(InspectionMarker marker) {
    if (marker.status == InspectionMarkerStatus.handled) return Colors.grey;
    if (marker.isSosAlarm) return const Color(0xFF991B1B);
    switch (marker.type) {
      case 'fall':
        return Colors.red;
      case 'crack':
        return Colors.amber;
      case 'robot':
        return Colors.blue;
      case 'target':
        return Colors.green;
      case 'obstacle':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  static IconData _markerIcon(InspectionMarker marker) {
    if (marker.isSosAlarm) return Icons.sos_outlined;
    switch (marker.type) {
      case 'sos':
        return Icons.sos_outlined;
      case 'fall':
        return Icons.personal_injury_outlined;
      case 'crack':
        return Icons.warning_amber_outlined;
      case 'robot':
        return Icons.smart_toy_outlined;
      case 'target':
        return Icons.flag_outlined;
      case 'obstacle':
        return Icons.report_problem_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground({required this.mapInfo});

  final InspectionMapInfo mapInfo;

  @override
  Widget build(BuildContext context) {
    final asset = mapInfo.imageAsset;
    if (asset == null || asset.isEmpty) {
      return const CustomPaint(painter: _GridPainter());
    }
    return Image.asset(
      asset,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => const CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _NavigationStatusPanel extends StatelessWidget {
  const _NavigationStatusPanel({required this.status});

  final InspectionNavigationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _StatusText(label: '导航状态', value: status.navigationStatus ?? '-'),
          _StatusText(label: '避障状态', value: status.obstacleStatus ?? '-'),
          if (status.robotX != null && status.robotY != null)
            _StatusText(
              label: '小车当前位置',
              value:
                  '${status.robotX!.toStringAsFixed(0)}, ${status.robotY!.toStringAsFixed(0)}',
            ),
          if (status.targetX != null && status.targetY != null)
            _StatusText(
              label: status.targetName ?? '目标点',
              value:
                  '${status.targetX!.toStringAsFixed(0)}, ${status.targetY!.toStringAsFixed(0)}',
            ),
          if (status.displayMessage != '-')
            _StatusText(label: '说明', value: status.displayMessage),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label：$value');
  }
}

class _MapState {
  const _MapState({
    required this.mapInfo,
    required this.markers,
    required this.navigationStatus,
  });

  final InspectionMapInfo mapInfo;
  final List<InspectionMarker> markers;
  final InspectionNavigationStatus? navigationStatus;
}
