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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MapState> _load() async {
    final mapInfo = await InspectionService.getMapInfo();
    final markers = await InspectionService.getMarkers();
    return _MapState(mapInfo: mapInfo, markers: markers);
  }

  void _replaceMarker(InspectionMarker marker) {
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
            onPressed: () => setState(() => _future = _load()),
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
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: Text('暂无巡检地图数据'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(state.mapInfo.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _MapCanvas(
                mapInfo: state.mapInfo,
                markers: state.markers,
                onTapMarker: _showDetail,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _LegendDot(color: Colors.red, label: '跌倒'),
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
    required this.onTapMarker,
  });

  final InspectionMapInfo mapInfo;
  final List<InspectionMarker> markers;
  final ValueChanged<InspectionMarker> onTapMarker;

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                    for (final marker in markers)
                      Positioned(
                        left: marker.x * scale - 14,
                        top: marker.y * scale - 14,
                        child: Opacity(
                          key: ValueKey('marker-opacity-${marker.id}'),
                          opacity: marker.status == InspectionMarkerStatus.handled ? 0.42 : 1,
                          child: Tooltip(
                            message: marker.title,
                            child: InkWell(
                              key: ValueKey('marker-${marker.type}-${marker.id}'),
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => onTapMarker(marker),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _markerColor(marker),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 6,
                                      color: Color(0x33000000),
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _markerIcon(marker.type),
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
        );
      },
    );
  }

  static Color _markerColor(InspectionMarker marker) {
    if (marker.status == InspectionMarkerStatus.handled) return Colors.grey;
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

  static IconData _markerIcon(String type) {
    switch (type) {
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

class _MapState {
  const _MapState({
    required this.mapInfo,
    required this.markers,
  });

  final InspectionMapInfo mapInfo;
  final List<InspectionMarker> markers;
}
