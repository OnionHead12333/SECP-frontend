import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_medicine_progress.dart';

final class ElderMedicineReminderService {
  ElderMedicineReminderService._();

  static Future<ElderMedicineProgress> fetchTodayProgress({required int elderId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/medicine-reminders/today-progress',
      queryParameters: {'elderId': elderId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderMedicineProgress.fromJson(api.data!);
  }

  static Future<ElderMedicineProgress> confirmTaken({
    required int elderId,
    required int reminderId,
  }) async {
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
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderMedicineProgress.fromJson(api.data!);
  }

  /// 稍后提醒：调用后端顺延接口（默认顺延 10 分钟）。
  static Future<ElderMedicineProgress> snoozeMedicine({
    required int elderId,
    required int reminderId,
    int snoozeMinutes = 10,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/medicine-reminders/$reminderId/snooze',
      data: {
        'elderId': elderId,
        'snoozeMinutes': snoozeMinutes,
        'requestedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderMedicineProgress.fromJson(api.data!);
  }
}
