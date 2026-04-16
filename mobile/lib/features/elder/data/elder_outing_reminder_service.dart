import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_outing_status.dart';

final class ElderOutingReminderService {
  ElderOutingReminderService._();

  static ElderOutingStatus _mockStatus = ElderOutingStatus(
    locationEnabled: true,
    monitorStatus: 'normal',
    currentState: 'outside',
    outsideStartAt: DateTime.now().subtract(const Duration(minutes: 45)),
    lastUploadAt: DateTime.now().subtract(const Duration(minutes: 2)),
    lastLocationDesc: '社区东门附近（模拟）',
  );

  static Future<ElderOutingStatus> fetchStatus({required int elderId}) async {
    if (AppConfig.useMockLocation) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      return _mockStatus;
    }

    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/elder/outing/status',
        queryParameters: {'elderId': elderId},
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      return ElderOutingStatus.fromJson(api.data!);
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _mockStatus;
    }
  }

  static Future<void> uploadLocation({
    required int elderId,
    required double latitude,
    required double longitude,
    required String source,
  }) async {
    if (AppConfig.useMockLocation) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _mockStatus = ElderOutingStatus(
        locationEnabled: true,
        monitorStatus: 'normal',
        currentState: 'outside',
        outsideStartAt: _mockStatus.outsideStartAt ?? DateTime.now().subtract(const Duration(minutes: 1)),
        lastUploadAt: DateTime.now(),
        lastLocationDesc: '纬度 ${latitude.toStringAsFixed(5)} / 经度 ${longitude.toStringAsFixed(5)}（$source）',
      );
      return;
    }

    await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/location/upload',
      data: {
        'elderId': elderId,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}
