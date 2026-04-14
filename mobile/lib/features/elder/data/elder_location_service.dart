import 'dart:async';

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/app_config.dart';
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
    final permissionGranted = await _ensurePermission();
    final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    final latest = await _readCurrentPoint(saveToTrack: _track.isEmpty);
    _latest = latest;
    final state = ElderLocationState(
      permissionGranted: permissionGranted,
      serviceEnabled: serviceEnabled,
      autoUploadEnabled: permissionGranted && serviceEnabled,
      latestPoint: latest,
      uploadStatusText: latest == null ? '等待首次定位' : '定位已获取，等待后端联调',
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
    if (!permissionGranted || !serviceEnabled) return;
    _started = true;
    await uploadNow(phone);
    _schedule(phone, _latest);
  }

  static Future<void> stopAutoUpload() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _emit(_currentState.copyWith(autoUploadEnabled: false, isUploading: false, uploadStatusText: '自动采集已暂停'));
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
        _latest = point.copyWith(uploaded: true);
        _replaceLastPoint(_latest!);
        _emit(_currentState.copyWith(isUploading: false, latestPoint: _latest, autoUploadEnabled: true, permissionGranted: true, serviceEnabled: true, uploadStatusText: '定位已获取，上传成功', clearLastError: true));
      } on DioException catch (_) {
        _latest = point.copyWith(uploaded: false);
        _replaceLastPoint(_latest!);
        _emit(_currentState.copyWith(isUploading: false, latestPoint: _latest, autoUploadEnabled: true, permissionGranted: true, serviceEnabled: true, uploadStatusText: '定位已获取，等待后端接口', lastError: '后端接口暂未联通，轨迹已保存在本机页面供测试查看'));
      }
      if (_started) _schedule(phone, _latest);
    } catch (e) {
      _emit(_currentState.copyWith(isUploading: false, uploadStatusText: '定位获取失败', lastError: e.toString().replaceFirst('Exception: ', '')));
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
    _emit(_currentState.copyWith(permissionGranted: granted, serviceEnabled: enabled));
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
    if (!forceRequest && status.isDenied) {
      final requested = await Permission.location.request();
      if (requested.isGranted) {
        await Permission.locationAlways.request();
        return true;
      }
      return false;
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
  const ElderLocationState({this.permissionGranted = false, this.serviceEnabled = false, this.autoUploadEnabled = false, this.latestPoint, this.isUploading = false, this.usingMock = false, this.uploadStatusText = '待初始化', this.lastError});

  final bool permissionGranted;
  final bool serviceEnabled;
  final bool autoUploadEnabled;
  final ElderLocationPoint? latestPoint;
  final bool isUploading;
  final bool usingMock;
  final String uploadStatusText;
  final String? lastError;

  ElderLocationState copyWith({bool? permissionGranted, bool? serviceEnabled, bool? autoUploadEnabled, ElderLocationPoint? latestPoint, bool clearLatestPoint = false, bool? isUploading, bool? usingMock, String? uploadStatusText, String? lastError, bool clearLastError = false}) {
    return ElderLocationState(
      permissionGranted: permissionGranted ?? this.permissionGranted,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      latestPoint: clearLatestPoint ? null : (latestPoint ?? this.latestPoint),
      isUploading: isUploading ?? this.isUploading,
      usingMock: usingMock ?? this.usingMock,
      uploadStatusText: uploadStatusText ?? this.uploadStatusText,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
