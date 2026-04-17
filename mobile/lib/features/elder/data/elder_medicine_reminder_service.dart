import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_medicine_progress.dart';

final class ElderMedicineReminderService {
  ElderMedicineReminderService._();

  static ElderMedicineProgress _mockProgress = ElderMedicineProgress(
    plannedCount: 3,
    confirmedCount: 1,
    missedCount: 0,
    pendingCount: 2,
    completionPercent: 33.3,
    activeReminderId: 7001,
    medicineName: '降压药',
    doseDesc: '1 片',
    lastConfirmedAt: DateTime.now().subtract(const Duration(hours: 4)),
    nextReminderAt: DateTime.now().add(const Duration(minutes: 25)),
  );

  static Future<ElderMedicineProgress> fetchTodayProgress({required int elderId}) async {
    if (AppConfig.useMockLocation) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      return _mockProgress;
    }

    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/elder/medicine-reminders/today-progress',
        queryParameters: {'elderId': elderId},
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      _mockProgress = ElderMedicineProgress.fromJson(api.data!);
      return _mockProgress;
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _mockProgress;
    }
  }

  static Future<ElderMedicineProgress> confirmTaken({
    required int elderId,
    required int reminderId,
  }) async {
    if (AppConfig.useMockLocation) {
      return _confirmByMock();
    }

    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/elder/medicine-reminders/$reminderId/confirm',
        data: {
          'elderId': elderId,
          'confirmedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      _mockProgress = _mockProgress.copyWith(
        confirmedCount: (api.data!['confirmedCount'] as num?)?.toInt() ?? _mockProgress.confirmedCount,
        completionPercent: (api.data!['completionPercent'] as num?)?.toDouble() ?? _mockProgress.completionPercent,
        lastConfirmedAt: DateTime.now(),
      );
      return _mockProgress;
    } on DioException {
      return _confirmByMock();
    }
  }

  static Future<ElderMedicineProgress> postponeOnceMock({Duration after = const Duration(minutes: 1)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _mockProgress = _mockProgress.copyWith(nextReminderAt: DateTime.now().add(after));
    return _mockProgress;
  }

  static Future<ElderMedicineProgress> markMissedMock() async {
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
      nextReminderAt: DateTime.now().add(const Duration(hours: 6)),
    );
    return _mockProgress;
  }

  static Future<ElderMedicineProgress> _confirmByMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final confirmed = min(_mockProgress.confirmedCount + 1, _mockProgress.plannedCount);
    final pending = max(_mockProgress.plannedCount - confirmed - _mockProgress.missedCount, 0);
    final percent = _mockProgress.plannedCount == 0 ? 0.0 : (confirmed / _mockProgress.plannedCount * 100);
    _mockProgress = _mockProgress.copyWith(
      confirmedCount: confirmed,
      pendingCount: pending,
      completionPercent: percent,
      lastConfirmedAt: DateTime.now(),
      nextReminderAt: DateTime.now().add(const Duration(hours: 6)),
    );
    return _mockProgress;
  }
}

