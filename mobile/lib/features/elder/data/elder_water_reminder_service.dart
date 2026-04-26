import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_water_progress.dart';

final class ElderWaterReminderService {
  ElderWaterReminderService._();

  static ElderWaterProgress _mockProgress = ElderWaterProgress(
    plannedCount: 6,
    confirmedCount: 2,
    missedCount: 1,
    pendingCount: 3,
    completionPercent: 33.3,
    activeReminderId: 8001,
    lastConfirmedAt: DateTime.now().subtract(const Duration(hours: 2)),
    nextReminderAt: DateTime.now().add(const Duration(minutes: 40)),
  );

  static Future<ElderWaterProgress> postponeOnceMock({Duration after = const Duration(minutes: 1)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _mockProgress = _mockProgress.copyWith(nextReminderAt: DateTime.now().add(after));
    return _mockProgress;
  }

  static Future<ElderWaterProgress> markMissedMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final missed = min(_mockProgress.missedCount + 1, _mockProgress.plannedCount);
    final confirmed = min(_mockProgress.confirmedCount, _mockProgress.plannedCount - missed);
    final pending = max(_mockProgress.plannedCount - confirmed - missed, 0);
    final percent = _mockProgress.plannedCount == 0 ? 0.0 : (confirmed / _mockProgress.plannedCount * 100);
    _mockProgress = _mockProgress.copyWith(
      missedCount: missed,
      confirmedCount: confirmed,
      pendingCount: pending,
      completionPercent: percent,
      nextReminderAt: DateTime.now().add(const Duration(hours: 2)),
    );
    return _mockProgress;
  }

  static Future<ElderWaterProgress> fetchTodayProgress({required int elderId}) async {
    if (AppConfig.useMockReminders) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _mockProgress;
    }

    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/elder/water-reminders/today-progress',
        queryParameters: {'elderId': elderId},
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(
        body,
        (raw) => raw is Map<String, dynamic> ? raw : null,
      );
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      _mockProgress = ElderWaterProgress.fromJson(api.data!);
      return _mockProgress;
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _mockProgress;
    }
  }

  static Future<ElderWaterProgress> confirmWater({
    required int elderId,
    required int reminderId,
  }) async {
    if (AppConfig.useMockReminders) {
      return _confirmByMock();
    }

    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/elder/water-reminders/$reminderId/confirm',
        data: {
          'elderId': elderId,
          'confirmedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(
        body,
        (raw) => raw is Map<String, dynamic> ? raw : null,
      );
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      _mockProgress = ElderWaterProgress.fromJson(api.data!);
      return _mockProgress;
    } on DioException {
      return _confirmByMock();
    }
  }

  static Future<ElderWaterProgress> _confirmByMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final confirmed = min(_mockProgress.confirmedCount + 1, _mockProgress.plannedCount);
    final pending = max(_mockProgress.plannedCount - confirmed - _mockProgress.missedCount, 0);
    final percent = _mockProgress.plannedCount == 0 ? 0.0 : (confirmed / _mockProgress.plannedCount * 100);
    _mockProgress = _mockProgress.copyWith(
      confirmedCount: confirmed,
      pendingCount: pending,
      completionPercent: percent,
      lastConfirmedAt: DateTime.now(),
      nextReminderAt: DateTime.now().add(const Duration(hours: 2)),
    );
    return _mockProgress;
  }
}
