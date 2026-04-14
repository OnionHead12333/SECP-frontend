import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

/// 多图源可切换：默认高德栅格（国内易加载），可选 Esri / OSM-DE。
/// 高德为 Web 常用非官方瓦片地址，正式环境请改用合规 SDK 或自有瓦片服务。
class _RasterSpec {
  const _RasterSpec({
    required this.urlTemplate,
    this.subdomains = const [],
    required this.attribution,
    this.tileProvider,
    this.fallbackUrl,
  });

  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
  final TileProvider? tileProvider;
  final String? fallbackUrl;
}

class ChildLocationMap extends StatefulWidget {
  const ChildLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height,
    this.expandInParent = false,
  });

  final double latitude;
  final double longitude;
  final double? height;
  final bool expandInParent;

  static const _gaodeUa =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  /// 顺序：国内优先高德 → 全球 Esri → OSM 德国镜像（部分网络下比 osm.org 可用）
  static final List<_RasterSpec> _sources = [
    _RasterSpec(
      urlTemplate:
          'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
      subdomains: const ['1', '2', '3', '4'],
      attribution: '高德底图（演示）',
      tileProvider: NetworkTileProvider(
        headers: {
          'User-Agent': _gaodeUa,
          'Referer': 'https://www.amap.com/',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ),
      fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
    ),
    const _RasterSpec(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Esri, Maxar, GeoEye, Earthstar Geographics, GIS 用户社区',
      fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
    ),
    const _RasterSpec(
      urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap 贡献者, OpenStreetMap Germany',
    ),
  ];

  @override
  State<ChildLocationMap> createState() => _ChildLocationMapState();
}

class _ChildLocationMapState extends State<ChildLocationMap> {
  int _sourceIndex = 0;

  double _defaultHeight(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return (sh * 0.42).clamp(300.0, 560.0);
  }

  Widget _attributionLine(BuildContext context, String text) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 6,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
      ),
    );
  }

  Widget _sourceChip(BuildContext context) {
    final n = ChildLocationMap._sources.length;
    final idx = _sourceIndex % n;
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        elevation: 1,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => setState(() => _sourceIndex = (_sourceIndex + 1) % n),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '图源 ${idx + 1}/$n · 点按切换',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapStack(BuildContext context, LatLng point) {
    final spec = ChildLocationMap._sources[_sourceIndex % ChildLocationMap._sources.length];

    return Stack(
      fit: widget.expandInParent ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: ValueKey<int>(_sourceIndex),
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 18,
              backgroundColor: const Color(0xFFB8C5D8),
            ),
            children: [
              TileLayer(
                urlTemplate: spec.urlTemplate,
                subdomains: spec.subdomains,
                userAgentPackageName: 'smart_elderly_care_mobile',
                tileProvider: spec.tileProvider,
                fallbackUrl: spec.fallbackUrl,
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.bottomCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                      shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _sourceChip(context),
        _attributionLine(context, '${spec.attribution} · 仅供演示'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);

    final mapBody = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.expandInParent
          ? _mapStack(context, point)
          : SizedBox(
              height: widget.height ?? _defaultHeight(context),
              width: double.infinity,
              child: _mapStack(context, point),
            ),
    );

    if (widget.expandInParent) {
      return mapBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        mapBody,
        const SizedBox(height: 6),
        Text(
          '若仍为灰底或错位，请点地图右上角「图源」依次切换；正式版请接入高德/天地图等合规服务。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _RealAmapView extends StatelessWidget {
  const _RealAmapView({
    required this.latitude,
    required this.longitude,
    required this.track,
    required this.route,
  });

  final double latitude;
  final double longitude;
  final List<({double latitude, double longitude})> track;
  final List<({double latitude, double longitude})> route;

  @override
  Widget build(BuildContext context) {
    final current = LatLng(latitude, longitude);
    final routePoints = route.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final trackPoints = track.map((e) => LatLng(e.latitude, e.longitude)).toList();

    final markers = <Marker>{
      Marker(position: current, infoWindow: const InfoWindow(title: '老人当前位置', snippet: '当前定位点'))..setIdForCopy('elder-current'),
    };

    if (routePoints.isNotEmpty) {
      markers.add(Marker(position: routePoints.last, infoWindow: const InfoWindow(title: '家', snippet: '老人回家目的地'))..setIdForCopy('elder-home'));
    }

    final polylines = <Polyline>{};
    if (trackPoints.length > 1) {
      polylines.add(Polyline(points: trackPoints, width: 6, color: const Color(0xFF2563EB))..setIdForCopy('elder-track'));
    }
    if (routePoints.length > 1) {
      polylines.add(Polyline(points: routePoints, width: 7, color: const Color(0xFFEA580C))..setIdForCopy('elder-route'));
    }

    return AMapWidget(
      apiKey: const AMapApiKey(androidKey: AppConfig.amapAndroidKey, iosKey: AppConfig.amapIosKey),
      privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
      initialCameraPosition: CameraPosition(target: current, zoom: 17),
      mapType: MapType.normal,
      markers: markers,
      polylines: polylines,
      scaleEnabled: true,
      compassEnabled: true,
      trafficEnabled: false,
      buildingsEnabled: true,
      labelsEnabled: true,
      touchPoiEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
    );
  }
}

class _OfflineAmapStyleView extends StatelessWidget {
  const _OfflineAmapStyleView({
    required this.latitude,
    required this.longitude,
    required this.track,
    required this.route,
  });

  final double latitude;
  final double longitude;
  final List<({double latitude, double longitude})> track;
  final List<({double latitude, double longitude})> route;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
      ),
      child: CustomPaint(
        painter: _GaodeStyleTrackPainter(
          currentLatitude: latitude,
          currentLongitude: longitude,
          track: track,
          route: route,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GaodeStyleTrackPainter extends CustomPainter {
  const _GaodeStyleTrackPainter({
    required this.currentLatitude,
    required this.currentLongitude,
    required this.track,
    required this.route,
  });

  final double currentLatitude;
  final double currentLongitude;
  final List<({double latitude, double longitude})> track;
  final List<({double latitude, double longitude})> route;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    final points = _normalizePoints(size, [...track, ...route, (latitude: currentLatitude, longitude: currentLongitude)]);
    if (points.isEmpty) return;

    final trackCount = track.length;
    final routeStart = trackCount;

    if (trackCount > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1).take(trackCount - 1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, Paint()..color = const Color(0x552563EB)..strokeWidth = 10..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(path, Paint()..color = const Color(0xFF2563EB)..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    if (route.length > 1) {
      final routePath = Path()..moveTo(points[routeStart].dx, points[routeStart].dy);
      for (final point in points.skip(routeStart + 1).take(route.length - 1)) {
        routePath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(routePath, Paint()..color = const Color(0xFFEA580C)..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    if (trackCount > 0) {
      canvas.drawCircle(points.first, 6, Paint()..color = const Color(0xFF0F766E));
    }

    if (route.length > 1) {
      canvas.drawCircle(points[routeStart], 8, Paint()..color = const Color(0xFFDC2626));
      canvas.drawCircle(points[routeStart + route.length - 1], 8, Paint()..color = const Color(0xFF166534));
    } else {
      canvas.drawCircle(points.last, 8, Paint()..color = const Color(0xFFDC2626));
    }

    if (route.length > 2) {
      for (final point in points.skip(routeStart + 1).take(route.length - 2)) {
        canvas.drawCircle(point, 5, Paint()..color = const Color(0xFFEA580C));
      }
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final borderPaint = Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);

    final gridPaint = Paint()..color = const Color(0x120F172A);
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), gridPaint);
      canvas.drawLine(Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), gridPaint);
    }

    final roadPaint = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 16..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(24, size.height - 34), Offset(size.width - 28, 28), roadPaint);
    canvas.drawLine(Offset(18, size.height * 0.32), Offset(size.width - 18, size.height * 0.32), roadPaint);
    canvas.drawLine(Offset(size.width * 0.68, 18), Offset(size.width * 0.68, size.height - 18), roadPaint);
  }

  List<Offset> _normalizePoints(Size size, List<({double latitude, double longitude})> raw) {
    if (raw.isEmpty) return const [];

    final minLat = raw.map((e) => e.latitude).reduce(math.min);
    final maxLat = raw.map((e) => e.latitude).reduce(math.max);
    final minLng = raw.map((e) => e.longitude).reduce(math.min);
    final maxLng = raw.map((e) => e.longitude).reduce(math.max);
    final latSpan = math.max(maxLat - minLat, 0.0002);
    final lngSpan = math.max(maxLng - minLng, 0.0002);

    return raw.map((point) {
      final dx = ((point.longitude - minLng) / lngSpan) * (size.width - 24) + 12;
      final dy = size.height - (((point.latitude - minLat) / latSpan) * (size.height - 24) + 12);
      return Offset(dx, dy);
    }).toList();
  }

  @override
  bool shouldRepaint(covariant _GaodeStyleTrackPainter oldDelegate) {
    return oldDelegate.currentLatitude != currentLatitude || oldDelegate.currentLongitude != currentLongitude || oldDelegate.track != track || oldDelegate.route != route;
  }
}
