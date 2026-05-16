import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_exercise_progress.dart';

final class ElderExerciseReminderService {
  ElderExerciseReminderService._();

  static Future<ElderExerciseProgress> fetchTodayProgress({required int elderId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/exercise-reminders/today-progress',
      queryParameters: {'elderId': elderId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderExerciseProgress.fromJson(api.data!);
  }

  static Future<ElderExerciseProgress> startExercise({
    required int elderId,
    required int reminderId,
  }) async {
    await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/exercise-reminders/$reminderId/start',
      data: {
        'elderId': elderId,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return fetchTodayProgress(elderId: elderId);
  }

  static Future<ElderExerciseProgress> completeExercise({
    required int elderId,
    required int reminderId,
    required String source,
  }) async {
    final sourceNormalized = source == 'sensor' ? 'sensor' : 'manual';

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
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderExerciseProgress.fromJson(api.data!);
  }
}
