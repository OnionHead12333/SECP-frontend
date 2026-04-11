import 'dart:math';

import '../models/elder_location_point.dart';

final class ElderLocationMockService {
  ElderLocationMockService._();

  static const Duration _normalInterval = Duration(minutes: 10);
  static final Map<String, List<ElderLocationPoint>> _trackStore = {
    '13800138001': [
      ElderLocationPoint(
        latitude: 31.23040,
        longitude: 121.47370,
        label: '家附近（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        isHome: true,
      ),
      ElderLocationPoint(
        latitude: 31.23042,
        longitude: 121.47368,
        label: '小区门口（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        isHome: false,
      ),
      ElderLocationPoint(
        latitude: 31.23055,
        longitude: 121.47392,
        label: '便利店附近（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        isHome: false,
      ),
    ],
  };

  static Future<List<ElderLocationPoint>> fetchTrack(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final points = _trackStore[phone.trim()] ?? const <ElderLocationPoint>[];
    return [...points]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  static Future<ElderLocationPoint> uploadCurrentLocation(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = phone.trim();
    final current = [...(_trackStore[normalized] ?? const <ElderLocationPoint>[])];
    final seed = DateTime.now().millisecond / 10000;
    final baseLat = current.isEmpty ? 31.23040 : current.first.latitude;
    final baseLng = current.isEmpty ? 121.47370 : current.first.longitude;
    final outside = DateTime.now().minute.isOdd;
    final jitter = (Random().nextDouble() + seed) / 1000;
    final point = ElderLocationPoint(
      latitude: outside ? baseLat + jitter : 31.23040 + jitter / 6,
      longitude: outside ? baseLng + jitter : 121.47370 + jitter / 6,
      label: outside ? '户外轨迹点（高德演示）' : '家附近轨迹点（高德演示）',
      recordedAt: DateTime.now(),
      isHome: !outside,
    );
    _trackStore[normalized] = [point, ...current];
    return point;
  }

  static String uploadIntervalText({required bool isOutside}) {
    if (isOutside) return '当前模拟为外出阶段，建议 3~5 分钟上传一次高德定位';
    return '当前模拟为常规阶段，建议每 ${_normalInterval.inMinutes} 分钟上传一次高德定位';
  }
}
