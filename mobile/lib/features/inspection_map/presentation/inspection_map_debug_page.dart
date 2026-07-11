import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/inspection_map_api_repository.dart';
import '../data/inspection_map_mock_repository.dart';
import '../data/inspection_map_repository.dart';
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
  Map<String, dynamic>? _initialPoseJson;
  Map<String, dynamic>? _navGoalJson;
  String? _errorMessage;

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
    final payload = {
      'type':
          _clickMode == _ClickMode.initialPose ? 'initial_pose' : 'nav_goal',
      'frame_id': mapInfo.frameId,
      'x': _round(map.x),
      'y': _round(map.y),
      'yaw': 0.0,
    };

    setState(() {
      _selectedPixel = pixel;
      _selectedMap = map;
      if (_clickMode == _ClickMode.initialPose) {
        _initialPoseJson = payload;
      } else {
        _navGoalJson = payload;
      }
    });
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
                              ..._markers.map(_buildMarker),
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
          onTap: () => _showMarkerDetail(marker),
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
              label: const Text('Start navigation'),
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
