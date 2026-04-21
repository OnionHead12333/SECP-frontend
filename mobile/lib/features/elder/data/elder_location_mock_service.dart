import 'dart:math';

import '../../../core/config/app_config.dart';
import '../models/elder_location_point.dart';

final class ElderLocationMockService {
  ElderLocationMockService._();

  static const int _maxTrackPoints = 30;

  static final Map<String, List<ElderLocationPoint>> _trackStore = {
    '13800138001': _seedTrack(),
    '': _seedTrack(),
  };

  static Future<List<ElderLocationPoint>> fetchTrack(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final points = _trackStore[_normalizePhone(phone)] ?? const <ElderLocationPoint>[];
    return [...points]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  static Future<ElderLocationPoint> uploadCurrentLocation(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = _normalizePhone(phone);
    final current = [...(_trackStore[normalized] ?? _seedTrack())]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latest = current.first;
    final outside = DateTime.now().minute.isOdd;
    final jitter = (Random().nextDouble() + DateTime.now().millisecond / 1000) / 1400;
    final point = ElderLocationPoint(
      latitude: outside ? latest.latitude + jitter : 31.23040 + jitter / 5,
      longitude: outside ? latest.longitude + jitter * 1.15 : 121.47370 + jitter / 5,
      label: outside ? '户外轨迹点（高德演示）' : '家附近轨迹点（高德演示）',
      recordedAt: DateTime.now(),
      isHome: !outside,
      source: 'gaode-mock',
      locationType: outside ? 'outdoor' : 'indoor',
      uploaded: false,
    );
    _trackStore[normalized] = [point, ...current].take(_maxTrackPoints).toList();
    return point;
  }

  static String uploadIntervalText({required bool isOutside}) {
    if (AppConfig.useMockLocation) {
      return isOutside ? '当前为蓝牙断开后的高德模拟导航，每 12 秒刷新一次轨迹，方便前端测试' : '当前为居家守护模拟状态，每 12 秒刷新一次轨迹，方便前端测试';
    }
    return isOutside ? '当前为外出阶段，建议 3~5 分钟上传一次高德定位' : '当前为常规阶段，建议每 10 分钟上传一次高德定位';
  }

  static List<ElderLocationPoint> _seedTrack() {
    final now = DateTime.now();
    return [
      ElderLocationPoint(
        latitude: 31.23218,
        longitude: 121.47502,
        label: '社区东门（高德演示）',
        recordedAt: now.subtract(const Duration(minutes: 18)),
        isHome: false,
        source: 'gaode-mock',
        locationType: 'outdoor',
      ),
      ElderLocationPoint(
        latitude: 31.23128,
        longitude: 121.47440,
        label: '家附近路口（高德演示）',
        recordedAt: now.subtract(const Duration(minutes: 12)),
        isHome: true,
        source: 'gaode-mock',
        locationType: 'indoor',
      ),
      ElderLocationPoint(
        latitude: 31.23072,
        longitude: 121.47402,
        label: '单元楼下（高德演示）',
        recordedAt: now.subtract(const Duration(minutes: 6)),
        isHome: true,
        source: 'gaode-mock',
        locationType: 'indoor',
      ),
      ElderLocationPoint(
        latitude: 31.23040,
        longitude: 121.47370,
        label: '家中（高德演示）',
        recordedAt: now.subtract(const Duration(minutes: 1)),
        isHome: true,
        source: 'gaode-mock',
        locationType: 'indoor',
      ),
    ].take(_maxTrackPoints).toList();
  }

  static String _normalizePhone(String phone) => phone.trim();
}
