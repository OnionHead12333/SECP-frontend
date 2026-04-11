import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/app_config.dart';
import 'elder_location_api.dart';
import '../models/elder_location_point.dart';

final class ElderLocationService {
  ElderLocationService._();

  static const Duration _normalInterval = Duration(minutes: 10);
  static const Duration _outsideInterval = Duration(minutes: 5);

  static final Map<String, List<ElderLocationPoint>> _mockTrackStore = {
    '13800138001': [
      ElderLocationPoint(
        latitude: 31.23040,
        longitude: 121.47370,
        label: '家附近（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        isHome: true,
        uploaded: true,
      ),
      ElderLocationPoint(
        latitude: 31.23042,
        longitude: 121.47368,
        label: '小区门口（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        isHome: false,
        uploaded: true,
      ),
      ElderLocationPoint(
        latitude: 31.23055,
        longitude: 121.47392,
        label: '便利店附近（高德演示）',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        isHome: false,
        uploaded: true,
      ),
    ],
  };

  static Timer? _timer;
  static bool _started = false;
  static bool _uploading = false;
  static ElderLocationPoint? _latest;
  static final StreamController<ElderLocationState> _controller =
      StreamController<ElderLocationState>.broadcast();

  static Stream<ElderLocationState> get stream => _controller.stream;

  static Future<ElderLocationState> initialize(String phone) async {
    if (AppConfig.useMockLocation) {
      final track = await fetchTrack(phone);
      _latest = track.isEmpty ? null : track.first;
      final state = ElderLocationState(
        permissionGranted: true,
        serviceEnabled: true,
        autoUploadEnabled: true,
        latestPoint: _latest,
        isUploading: false,
        usingMock: true,
      );
      _emit(state);
      return state;
    }

    final permission = await _ensurePermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final latest = await _safeReadCurrentPoint();
    _latest = latest;
    final state = ElderLocationState(
      permissionGranted: permission,
      serviceEnabled: serviceEnabled,
      autoUploadEnabled: permission && serviceEnabled,
      latestPoint: latest,
      isUploading: false,
      usingMock: false,
    );
    _emit(state);
    return state;
  }

  static Future<List<ElderLocationPoint>> fetchTrack(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (AppConfig.useMockLocation) {
      final points = _mockTrackStore[phone.trim()] ?? const <ElderLocationPoint>[];
      return [...points]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }
    if (_latest == null) return const [];
    return [_latest!];
  }

  static Future<void> startAutoUpload(String phone) async {
    if (_started) return;
    final state = await initialize(phone);
    if (!state.permissionGranted || !state.serviceEnabled) return;
    _started = true;
    await uploadNow(phone);
    _schedule(phone, state.latestPoint);
  }

  static Future<void> stopAutoUpload() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    final current = _currentState.copyWith(autoUploadEnabled: false, isUploading: false);
    _emit(current);
  }

  static Future<void> uploadNow(String phone) async {
    if (_uploading) return;
    _uploading = true;
    _emit(_currentState.copyWith(isUploading: true));
    try {
      final point = AppConfig.useMockLocation
          ? await _mockUpload(phone)
          : await _realUpload();
      _latest = point;
      _emit(
        _currentState.copyWith(
          isUploading: false,
          latestPoint: point,
          autoUploadEnabled: true,
          permissionGranted: true,
          serviceEnabled: true,
        ),
      );
      if (_started) _schedule(phone, point);
    } catch (_) {
      _emit(_currentState.copyWith(isUploading: false));
      rethrow;
    } finally {
      _uploading = false;
    }
  }

  static Future<bool> requestPermission() async {
    if (AppConfig.useMockLocation) {
      _emit(_currentState.copyWith(permissionGranted: true, serviceEnabled: true));
      return true;
    }
    final granted = await _ensurePermission(forceRequest: true);
    final enabled = await Geolocator.isLocationServiceEnabled();
    _emit(_currentState.copyWith(permissionGranted: granted, serviceEnabled: enabled));
    return granted;
  }

  static String uploadIntervalText({required bool isOutside}) {
    if (isOutside) return '当前模拟为外出阶段，建议每 ${_outsideInterval.inMinutes} 分钟自动上传一次高德定位';
    return '当前模拟为常规阶段，建议每 ${_normalInterval.inMinutes} 分钟自动上传一次高德定位';
  }

  static ElderLocationState get _currentState => _lastState ?? const ElderLocationState();
  static ElderLocationState? _lastState;

  static void _emit(ElderLocationState state) {
    _lastState = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  static void _schedule(String phone, ElderLocationPoint? point) {
    _timer?.cancel();
    final interval = point?.isHome == false ? _outsideInterval : _normalInterval;
    _timer = Timer(interval, () async {
      try {
        await uploadNow(phone);
      } catch (_) {}
    });
  }

  static Future<bool> _ensurePermission({bool forceRequest = false}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    final status = await Permission.location.status;
    if (status.isGranted) return true;
    if (!forceRequest && status.isDenied) {
      final requested = await Permission.location.request();
      return requested.isGranted;
    }
    if (forceRequest) {
      final requested = await Permission.location.request();
      if (requested.isGranted) {
        await Permission.locationAlways.request();
        return true;
      }
      return false;
    }
    return false;
  }

  static Future<ElderLocationPoint?> _safeReadCurrentPoint() async {
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      return _pointFromPosition(position, uploaded: false);
    } catch (_) {
      return null;
    }
  }

  static Future<ElderLocationPoint> _realUpload() async {
    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    final point = _pointFromPosition(position, uploaded: false);
    await ElderLocationApi.uploadLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      locationType: point.locationType,
      source: point.source,
      recordedAt: point.recordedAt,
    );
    return point.copyWith(uploaded: true);
  }

  static ElderLocationPoint _pointFromPosition(Position position, {required bool uploaded}) {
    final isHome = _looksHome(position.latitude, position.longitude);
    return ElderLocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      label: isHome ? '家附近（自动定位）' : '外出位置（自动定位）',
      recordedAt: position.timestamp ?? DateTime.now(),
      isHome: isHome,
      source: 'gaode',
      locationType: isHome ? 'indoor' : 'outdoor',
      uploaded: uploaded,
    );
  }

  static Future<ElderLocationPoint> _mockUpload(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = phone.trim();
    final current = [...(_mockTrackStore[normalized] ?? const <ElderLocationPoint>[])];
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
      source: 'gaode',
      locationType: outside ? 'outdoor' : 'indoor',
      uploaded: true,
    );
    _mockTrackStore[normalized] = [point, ...current];
    return point;
  }

  static bool _looksHome(double latitude, double longitude) {
    const homeLat = 31.23040;
    const homeLng = 121.47370;
    final latDiff = (latitude - homeLat).abs();
    final lngDiff = (longitude - homeLng).abs();
    return latDiff < 0.002 && lngDiff < 0.002;
  }
}

class ElderLocationState {
  const ElderLocationState({
    this.permissionGranted = false,
    this.serviceEnabled = false,
    this.autoUploadEnabled = false,
    this.latestPoint,
    this.isUploading = false,
    this.usingMock = false,
  });

  final bool permissionGranted;
  final bool serviceEnabled;
  final bool autoUploadEnabled;
  final ElderLocationPoint? latestPoint;
  final bool isUploading;
  final bool usingMock;

  ElderLocationState copyWith({
    bool? permissionGranted,
    bool? serviceEnabled,
    bool? autoUploadEnabled,
    ElderLocationPoint? latestPoint,
    bool clearLatestPoint = false,
    bool? isUploading,
    bool? usingMock,
  }) {
    return ElderLocationState(
      permissionGranted: permissionGranted ?? this.permissionGranted,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      latestPoint: clearLatestPoint ? null : (latestPoint ?? this.latestPoint),
      isUploading: isUploading ?? this.isUploading,
      usingMock: usingMock ?? this.usingMock,
    );
  }
}
