import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

/// 子女端地图：mock/自绘 时用 [_OfflineAmapStyleView]；否则用高德 [AMapWidget]。
class ChildLocationMap extends StatelessWidget {
  const ChildLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.track = const [],
    this.route = const [],
    this.height,
    this.expandInParent = false,
    /// 为 true 时不创建 [AMapWidget]（仅自绘底图+轨迹）。子女端多 Tab 若与
    /// [AppConfig.useMockLocation]==false 叠加，会同时出现多个高德原生子视图，易闪退。
    this.useOfflinePainter = false,
  });

  final double latitude;
  final double longitude;
  final List<({double latitude, double longitude})> track;
  final List<({double latitude, double longitude})> route;
  final double? height;
  final bool expandInParent;
  final bool useOfflinePainter;

  double _defaultHeight(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return (sh * 0.42).clamp(300.0, 560.0);
  }

  @override
  Widget build(BuildContext context) {
    final useOffline = AppConfig.useMockLocation || useOfflinePainter;
    final mapCore = useOffline
        ? _OfflineAmapStyleView(
            latitude: latitude,
            longitude: longitude,
            track: track,
            route: route,
          )
        : _RealAmapView(
            latitude: latitude,
            longitude: longitude,
            track: track,
            route: route,
          );

    final mapBody = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: expandInParent
          ? mapCore
          : SizedBox(
              height: height ?? _defaultHeight(context),
              width: double.infinity,
              child: mapCore,
            ),
    );

    if (expandInParent) {
      return mapBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        mapBody,
        const SizedBox(height: 6),
        Text(
          useOffline
              ? (useOfflinePainter
                  ? '子女端为稳定性使用自绘地图（不加载高德 SDK）。需原生地图请改组件策略并避免同屏多实例。'
                  : '当前为本地演示轨迹；联调真实定位请使用 flutter run --dart-define=USE_MOCK_LOCATION=false')
              : '已使用高德地图 SDK 展示位置与轨迹。',
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
      Marker(
        position: current,
        infoWindow: const InfoWindow(title: '老人当前位置', snippet: '当前定位点'),
      )..setIdForCopy('elder-current'),
    };

    if (routePoints.isNotEmpty) {
      markers.add(
        Marker(
          position: routePoints.last,
          infoWindow: const InfoWindow(title: '家', snippet: '老人回家目的地'),
        )..setIdForCopy('elder-home'),
      );
    }

    final polylines = <Polyline>{};
    if (trackPoints.length > 1) {
      polylines.add(
        Polyline(points: trackPoints, width: 6, color: const Color(0xFF2563EB))..setIdForCopy('elder-track'),
      );
    }
    if (routePoints.length > 1) {
      polylines.add(
        Polyline(points: routePoints, width: 7, color: const Color(0xFFEA580C))..setIdForCopy('elder-route'),
      );
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
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x552563EB)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    if (route.length > 1) {
      final routePath = Path()..moveTo(points[routeStart].dx, points[routeStart].dy);
      for (final point in points.skip(routeStart + 1).take(route.length - 1)) {
        routePath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        routePath,
        Paint()
          ..color = const Color(0xFFEA580C)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
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
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);

    final gridPaint = Paint()..color = const Color(0x120F172A);
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), gridPaint);
      canvas.drawLine(Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), gridPaint);
    }

    final roadPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
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
    return oldDelegate.currentLatitude != currentLatitude ||
        oldDelegate.currentLongitude != currentLongitude ||
        oldDelegate.track != track ||
        oldDelegate.route != route;
  }
}
