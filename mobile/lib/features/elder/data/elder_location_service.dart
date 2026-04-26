import 'dart:async';

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/app_config.dart';
import '../models/elder_location_guard_setting.dart';
import '../models/elder_location_point.dart';
import 'elder_location_api.dart';
import 'elder_location_mock_service.dart';

final class ElderLocationService {
  ElderLocationService._();

  static const Duration _normalInterval = Duration(minutes: 10);
  static const Duration _outsideInterval = Duration(minutes: 5);
  static const Duration _debugInterval = Duration(seconds: 12);
  static const int _maxTrackPoints = 5;

  static final StreamController<ElderLocationState> _controller = StreamController<ElderLocationState>.broadcast();

  static Timer? _timer;
  static bool _started = false;
  static bool _uploading = false;
  static bool _amapConfigured = false;
  static final List<ElderLocationPoint> _track = [];
  static ElderLocationPoint? _latest;
  static ElderLocationState? _lastState;

  static Stream<ElderLocationState> get stream => _controller.stream;
  static bool get isDebugFastMode => kDebugMode || AppConfig.useMockLocation;

  static Future<ElderLocationState> initialize(String phone) async {
    if (AppConfig.useMockLocation) {
      final track = await ElderLocationMockService.fetchTrack(phone);
      _track
        ..clear()
        ..addAll(track.reversed);
      _trimTrack();
      _latest = track.isEmpty ? null : track.first;
      final state = ElderLocationState(
        permissionGranted: true,
        serviceEnabled: true,
        latestPoint: _latest,
        usingMock: true,
        uploadStatusText: '蓝牙设备未接入，当前使用高德风格模拟轨迹进行前端测试',
      );
      _emit(state);
      return state;
    }

    _ensureAmapConfigured();
    final guard = await _fetchGuardSettingSafely();
    final permissionGranted = await _ensurePermission();
    final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    final backgroundGranted = (await Permission.locationAlways.status).isGranted;
    final syncedGuard = await _syncGuardPermissionSnapshot(
      permissionGranted: permissionGranted,
      serviceEnabled: serviceEnabled,
      backgroundGranted: backgroundGranted,
    );
    final effectiveGuard = syncedGuard ?? guard;
    final shouldRestore = effectiveGuard?.enabled == true && permissionGranted && serviceEnabled;
    _started = shouldRestore;
    final latest = permissionGranted && serviceEnabled ? await _readCurrentPoint(saveToTrack: _track.isEmpty) : null;
    _latest = latest;
    if (shouldRestore) _schedule(phone, latest);
    final state = ElderLocationState(
      permissionGranted: permissionGranted,
      backgroundPermissionGranted: backgroundGranted,
      serviceEnabled: serviceEnabled,
      autoUploadEnabled: shouldRestore,
      guardSetting: effectiveGuard,
      latestPoint: latest,
      uploadStatusText: _restoreStatusText(effectiveGuard, shouldRestore, latest),
      lastError: effectiveGuard?.lastError,
    );
    _emit(state);
    return state;
  }

  static Future<List<ElderLocationPoint>> fetchTrack(String phone) async {
    if (AppConfig.useMockLocation) {
      final track = await ElderLocationMockService.fetchTrack(phone);
      _track
        ..clear()
        ..addAll(track.reversed);
      _trimTrack();
      _latest = track.isEmpty ? _latest : track.first;
      return track;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return [..._track.reversed];
  }

  static Future<void> startAutoUpload(String phone) async {
    if (_started) return;
    if (AppConfig.useMockLocation) {
      _started = true;
      _emit(_currentState.copyWith(autoUploadEnabled: true, permissionGranted: true, serviceEnabled: true, usingMock: true, uploadStatusText: '蓝牙默认断开，已切到高德模拟导航轨迹', clearLastError: true));
      await uploadNow(phone);
      _schedule(phone, _latest);
      return;
    }

    final permissionGranted = await _ensurePermission();
    final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    final backgroundGranted = (await Permission.locationAlways.status).isGranted;
    if (!permissionGranted || !serviceEnabled) {
      throw Exception('定位权限未就绪，请先授权并开启系统定位服务');
    }
    ElderLocationGuardSetting? guard;
    try {
      guard = await ElderLocationApi.startGuard(
        mode: backgroundGranted ? 'background' : 'foreground',
        intervalSeconds: _normalInterval.inSeconds,
        outsideIntervalSeconds: _outsideInterval.inSeconds,
        foregroundGranted: permissionGranted && serviceEnabled,
        backgroundGranted: backgroundGranted,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('startGuard API failed: $e');
    }
    _started = true;
    _emit(_currentState.copyWith(guardSetting: guard, autoUploadEnabled: true, backgroundPermissionGranted: backgroundGranted, uploadStatusText: '定位守护已开启，正在上传首次定位', clearLastError: true));
    await uploadNow(phone);
    _schedule(phone, _latest);
  }

  static Future<void> stopAutoUpload() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    ElderLocationGuardSetting? guard;
    if (!AppConfig.useMockLocation) {
      try {
        guard = await ElderLocationApi.stopGuard();
      } catch (e) {
        if (kDebugMode) debugPrint('Stop location guard failed: $e');
      }
    }
    _emit(_currentState.copyWith(autoUploadEnabled: false, isUploading: false, guardSetting: guard, uploadStatusText: '自动采集已暂停'));
  }

  static Future<void> captureTestPoint(String phone) async {
    if (AppConfig.useMockLocation) {
      await uploadNow(phone);
      return;
    }
    final permissionGranted = await _ensurePermission();
    final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!permissionGranted || !serviceEnabled) {
      throw Exception('请先开启定位权限和系统定位服务');
    }
    await uploadNow(phone);
  }

  static Future<void> uploadNow(String phone) async {
    if (_uploading) return;
    _uploading = true;
    _emit(_currentState.copyWith(isUploading: true, uploadStatusText: '正在获取定位并尝试上传', clearLastError: true));
    try {
      if (AppConfig.useMockLocation) {
        final point = await ElderLocationMockService.uploadCurrentLocation(phone);
        _latest = point;
        _track.add(point);
        _trimTrack();
        _emit(_currentState.copyWith(isUploading: false, latestPoint: point, autoUploadEnabled: _started, permissionGranted: true, serviceEnabled: true, usingMock: true, uploadStatusText: '已生成模拟轨迹点，后端接口预留但当前不依赖后端', clearLastError: true));
        if (_started) _schedule(phone, point);
        return;
      }

      final point = await _readCurrentPoint(forceRefresh: true, saveToTrack: true);
      if (point == null) throw Exception('当前无法获取高德定位，请检查 Key / 包名 / SHA1 / 系统定位开关');
      try {
        await ElderLocationApi.uploadLocation(latitude: point.latitude, longitude: point.longitude, locationType: point.locationType, source: point.source, recordedAt: point.recordedAt);
        final guard = await _fetchGuardSettingSafely();
        _latest = point.copyWith(uploaded: true);
        _replaceLastPoint(_latest!);
        _emit(_currentState.copyWith(isUploading: false, latestPoint: _latest, guardSetting: guard, autoUploadEnabled: _started, permissionGranted: true, serviceEnabled: true, uploadStatusText: '定位已获取，上传成功', clearLastError: true));
      } on DioException catch (e) {
        final errorMessage = e.message ?? '后端定位接口请求失败';
        await _reportGuardErrorSafely(errorMessage);
        _latest = point.copyWith(uploaded: false);
        _replaceLastPoint(_latest!);
        _emit(_currentState.copyWith(isUploading: false, latestPoint: _latest, autoUploadEnabled: true, permissionGranted: true, serviceEnabled: true, uploadStatusText: '定位上传失败', lastError: errorMessage));
        rethrow;
      }
      if (_started) _schedule(phone, _latest);
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (!AppConfig.useMockLocation) await _reportGuardErrorSafely(errorMessage);
      _emit(_currentState.copyWith(isUploading: false, uploadStatusText: '定位获取失败', lastError: errorMessage));
      rethrow;
    } finally {
      _uploading = false;
    }
  }

  static Future<bool> requestPermission() async {
    if (AppConfig.useMockLocation) {
      _emit(_currentState.copyWith(permissionGranted: true, serviceEnabled: true, usingMock: true, uploadStatusText: '当前为前端测试模式，无需真机定位授权', clearLastError: true));
      return true;
    }
    final granted = await _ensurePermission(forceRequest: true);
    final enabled = await Permission.location.serviceStatus.isEnabled;
    final backgroundGranted = (await Permission.locationAlways.status).isGranted;
    final guard = await _syncGuardPermissionSnapshot(
      permissionGranted: granted,
      serviceEnabled: enabled,
      backgroundGranted: backgroundGranted,
    );
    await _syncPermissionSnapshot(permissionGranted: granted, serviceEnabled: enabled);
    _emit(_currentState.copyWith(permissionGranted: granted, backgroundPermissionGranted: backgroundGranted, serviceEnabled: enabled, guardSetting: guard));
    return granted;
  }

  static String uploadIntervalText({required bool isOutside}) {
    if (AppConfig.useMockLocation) {
      return ElderLocationMockService.uploadIntervalText(isOutside: isOutside);
    }
    if (kDebugMode) return '调试模式下已切换为每 ${_debugInterval.inSeconds} 秒自动采集一次，方便你原地测试移动轨迹';
    if (isOutside) return '当前为外出阶段，建议每 ${_outsideInterval.inMinutes} 分钟自动上传一次高德定位';
    return '当前为常规阶段，建议每 ${_normalInterval.inMinutes} 分钟自动上传一次高德定位';
  }

  static ElderLocationState get _currentState => _lastState ?? const ElderLocationState();

  static void _ensureAmapConfigured() {
    if (_amapConfigured || AppConfig.useMockLocation) return;
    AMapFlutterLocation.setApiKey(AppConfig.amapAndroidKey, AppConfig.amapIosKey);
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    _amapConfigured = true;
  }

  static Future<ElderLocationGuardSetting?> _fetchGuardSettingSafely() async {
    try {
      return await ElderLocationApi.fetchGuardSetting();
    } catch (e) {
      if (kDebugMode) debugPrint('Fetch location guard failed: $e');
      return null;
    }
  }

  static Future<ElderLocationGuardSetting?> _syncGuardPermissionSnapshot({
    required bool permissionGranted,
    required bool serviceEnabled,
    required bool backgroundGranted,
  }) async {
    try {
      return await ElderLocationApi.syncGuardPermissions(
        foregroundGranted: permissionGranted && serviceEnabled,
        backgroundGranted: backgroundGranted,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Sync location guard permissions failed: $e');
      return null;
    }
  }

  static Future<void> _reportGuardErrorSafely(String message) async {
    try {
      await ElderLocationApi.reportGuardError(message);
    } catch (e) {
      if (kDebugMode) debugPrint('Report location guard error failed: $e');
    }
  }

  static String _restoreStatusText(ElderLocationGuardSetting? guard, bool restored, ElderLocationPoint? latest) {
    if (guard == null) return latest == null ? '等待首次定位' : '定位已获取，等待后端联调';
    if (!guard.enabled) return '定位守护未开启';
    if (!restored) return '服务端记录为已开启，但当前权限或系统定位未就绪';
    return '已从服务端恢复定位守护状态';
  }

  static Future<void> _syncPermissionSnapshot({
    required bool permissionGranted,
    required bool serviceEnabled,
  }) async {
    try {
      await ElderLocationApi.updatePermission(
        foregroundGranted: permissionGranted && serviceEnabled,
        backgroundGranted: (await Permission.locationAlways.status).isGranted,
        permissionUpdatedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Sync location permission failed: $e');
    }
  }

  static void _emit(ElderLocationState state) {
    _lastState = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  static void _schedule(String phone, ElderLocationPoint? point) {
    _timer?.cancel();
    final interval = isDebugFastMode ? _debugInterval : (point?.isHome == false ? _outsideInterval : _normalInterval);
    _timer = Timer(interval, () async {
      try {
        await uploadNow(phone);
      } catch (_) {}
    });
  }

  static void _replaceLastPoint(ElderLocationPoint point) {
    if (_track.isEmpty) {
      _track.add(point);
      _trimTrack();
      return;
    }
    _track[_track.length - 1] = point;
  }

  static void _trimTrack() {
    if (_track.length <= _maxTrackPoints) return;
    _track.removeRange(0, _track.length - _maxTrackPoints);
  }

  static Future<bool> _ensurePermission({bool forceRequest = false}) async {
    final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!serviceEnabled) return false;

    final status = await Permission.location.status;
    if (status.isGranted) {
      await Permission.locationAlways.request();
      return true;
    }
    if (status.isPermanentlyDenied) {
      if (forceRequest) await openAppSettings();
      return false;
    }
    if (status.isDenied || forceRequest) {
      final requested = await Permission.location.request();
      if (requested.isGranted) {
        await Permission.locationAlways.request();
        return true;
      }
      if (requested.isPermanentlyDenied && forceRequest) await openAppSettings();
      return false;
    }
    return false;
  }

  static Future<ElderLocationPoint?> _readCurrentPoint({bool forceRefresh = false, bool saveToTrack = false}) async {
    _ensureAmapConfigured();
    final location = AMapFlutterLocation();
    final completer = Completer<ElderLocationPoint?>();
    StreamSubscription<Map<String, Object>>? subscription;

    location.setLocationOption(AMapLocationOption(locationMode: AMapLocationMode.Hight_Accuracy, desiredAccuracy: DesiredAccuracy.Best, needAddress: false, onceLocation: true, pausesLocationUpdatesAutomatically: false, locationInterval: 2000));

    subscription = location.onLocationChanged().listen((result) {
      if (completer.isCompleted) return;
      final errorCode = result['errorCode']?.toString();
      final errorInfo = result['errorInfo']?.toString();
      if (errorCode != null && errorCode != '0') {
        completer.completeError(Exception('高德定位失败，errorCode=$errorCode${errorInfo == null || errorInfo.isEmpty ? '' : '，errorInfo=$errorInfo'}'));
        return;
      }
      final latitude = (result['latitude'] as num?)?.toDouble();
      final longitude = (result['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        completer.completeError(Exception('高德定位失败，已回调但未返回有效经纬度：$result'));
        return;
      }
      completer.complete(_pointFromCoordinates(latitude, longitude, uploaded: !forceRefresh));
    });

    location.startLocation();
    final point = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('高德定位超时（8 秒无返回），请检查地图 SDK Key / 包名 / SHA1 / 网络 / 系统定位'),
    );
    location.stopLocation();
    await subscription.cancel();
    location.destroy();
    if (point != null && saveToTrack) {
      _track.add(point);
      _trimTrack();
    }
    return point;
  }

  static ElderLocationPoint _pointFromCoordinates(double latitude, double longitude, {required bool uploaded}) {
    final isHome = _looksHome(latitude, longitude);
    return ElderLocationPoint(latitude: latitude, longitude: longitude, label: isHome ? '家附近（高德定位）' : '外出位置（高德定位）', recordedAt: DateTime.now(), isHome: isHome, source: 'gaode', locationType: isHome ? 'indoor' : 'outdoor', uploaded: uploaded);
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
  const ElderLocationState({this.permissionGranted = false, this.backgroundPermissionGranted = false, this.serviceEnabled = false, this.autoUploadEnabled = false, this.guardSetting, this.latestPoint, this.isUploading = false, this.usingMock = false, this.uploadStatusText = '待初始化', this.lastError});

  final bool permissionGranted;
  final bool backgroundPermissionGranted;
  final bool serviceEnabled;
  final bool autoUploadEnabled;
  final ElderLocationGuardSetting? guardSetting;
  final ElderLocationPoint? latestPoint;
  final bool isUploading;
  final bool usingMock;
  final String uploadStatusText;
  final String? lastError;

  ElderLocationState copyWith({bool? permissionGranted, bool? backgroundPermissionGranted, bool? serviceEnabled, bool? autoUploadEnabled, ElderLocationGuardSetting? guardSetting, bool clearGuardSetting = false, ElderLocationPoint? latestPoint, bool clearLatestPoint = false, bool? isUploading, bool? usingMock, String? uploadStatusText, String? lastError, bool clearLastError = false}) {
    return ElderLocationState(
      permissionGranted: permissionGranted ?? this.permissionGranted,
      backgroundPermissionGranted: backgroundPermissionGranted ?? this.backgroundPermissionGranted,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      guardSetting: clearGuardSetting ? null : (guardSetting ?? this.guardSetting),
      latestPoint: clearLatestPoint ? null : (latestPoint ?? this.latestPoint),
      isUploading: isUploading ?? this.isUploading,
      usingMock: usingMock ?? this.usingMock,
      uploadStatusText: uploadStatusText ?? this.uploadStatusText,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
