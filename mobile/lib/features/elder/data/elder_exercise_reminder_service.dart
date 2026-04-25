import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_exercise_progress.dart';

final class ElderExerciseReminderService {
  ElderExerciseReminderService._();

  static ElderExerciseProgress _mockProgress = const ElderExerciseProgress(
    plannedCount: 2,
    completedCount: 0,
    missedCount: 0,
    pendingCount: 2,
    lastCompletionStatus: 'pending',
    lastCompletionSource: 'manual',
    activeReminderId: 9001,
    lastCompletedAt: null,
  );

  static Future<ElderExerciseProgress> fetchTodayProgress({required int elderId}) async {
    if (AppConfig.useMockReminders) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _mockProgress;
    }

    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/elder/exercise-reminders/today-progress',
        queryParameters: {'elderId': elderId},
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
      if (!api.isSuccess || api.data == null) throw Exception(api.message);
      _mockProgress = ElderExerciseProgress.fromJson(api.data!);
      return _mockProgress;
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _mockProgress;
    }
  }

  static Future<ElderExerciseProgress> startExercise({required int elderId, required int reminderId}) async {
    if (AppConfig.useMockReminders) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      return _mockProgress;
    }

    try {
      await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/elder/exercise-reminders/$reminderId/start',
        data: {
          'elderId': elderId,
          'startedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return _mockProgress;
    } on DioException {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _mockProgress;
    }
  }

  static Future<ElderExerciseProgress> completeExercise({
    required int elderId,
    required int reminderId,
    required String source,
  }) async {
    final sourceNormalized = source == 'sensor' ? 'sensor' : 'manual';

    if (AppConfig.useMockReminders) {
      return _completeByMock(source: sourceNormalized);
    }

    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/elder/exercise-reminders/$reminderId/complete',
        data: {
          'elderId': elderId,
          'confirmedAt': DateTime.now().toUtc().toIso8601String(),
          'source': sourceNormalized,
        },
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
      if (!api.isSuccess) throw Exception(api.message);
      final status = api.data?['status']?.toString() ?? (sourceNormalized == 'sensor' ? 'sensor_verified' : 'self_confirmed');
      _mockProgress = _mockProgress.copyWith(
        completedCount: min(_mockProgress.completedCount + 1, _mockProgress.plannedCount),
        pendingCount: max(_mockProgress.pendingCount - 1, 0),
        lastCompletionStatus: status,
        lastCompletionSource: sourceNormalized,
        lastCompletedAt: DateTime.now(),
      );
      return _mockProgress;
    } on DioException {
      return _completeByMock(source: sourceNormalized);
    }
  }

  static Future<ElderExerciseProgress> _completeByMock({required String source}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final completed = min(_mockProgress.completedCount + 1, _mockProgress.plannedCount);
    final pending = max(_mockProgress.plannedCount - completed - _mockProgress.missedCount, 0);
    _mockProgress = _mockProgress.copyWith(
      completedCount: completed,
      pendingCount: pending,
      lastCompletionStatus: source == 'sensor' ? 'sensor_verified' : 'self_confirmed',
      lastCompletionSource: source,
      lastCompletedAt: DateTime.now(),
    );
    return _mockProgress;
  }
}
