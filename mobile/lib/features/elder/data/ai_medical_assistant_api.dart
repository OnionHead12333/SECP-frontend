import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/ai_consultation_model.dart';

final class AiMedicalAssistantApi {
  AiMedicalAssistantApi._();

  static const _base = '/elderly/ai/consultations';

  static Future<AiConsultationResponse> createConsultation({
    required int elderlyId,
    required String inputText,
    required String inputType,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      _base,
      data: {
        'elderlyId': elderlyId,
        'inputText': inputText,
        'inputType': inputType,
      },
    );
    return _parseData(res.data, AiConsultationResponse.fromJson);
  }

  static Future<AiConsultationDetail> getConsultationDetail(int id) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('$_base/$id');
    return _parseData(res.data, AiConsultationDetail.fromJson);
  }

  static Future<AiConsultationResponse> sendMessage({
    required int id,
    required String messageContent,
    required String messageType,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_base/$id/messages',
      data: {'messageContent': messageContent, 'messageType': messageType},
    );
    return _parseData(res.data, AiConsultationResponse.fromJson);
  }

  static Future<AiNotifyFamilyResponse> notifyFamily(int id) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>('$_base/$id/notify-family');
    return _parseData(res.data, AiNotifyFamilyResponse.fromJson);
  }

  static Future<void> submitFeedback(int id, AiFeedbackRequestModel request) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '$_base/$id/feedback',
      data: request.toJson(),
    );
    final api = ApiResponse.fromJson(res.data ?? const {}, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
  }

  static Future<List<AiConsultationHistoryItem>> getConsultationHistory({
    required int elderlyId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      _base,
      queryParameters: {'elderlyId': elderlyId, 'page': page, 'pageSize': pageSize},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) {
      if (raw is List) return raw;
      return null;
    });
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    final items = api.data as List;
    return items
        .whereType<Map>()
        .map((e) => AiConsultationHistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<RecommendedDepartment>> getRecommendedDepartments(int id) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('$_base/$id/recommended-departments');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is List ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return (api.data as List)
        .whereType<Map>()
        .map((e) => RecommendedDepartment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static T _parseData<T>(Map<String, dynamic>? body, T Function(Map<String, dynamic>) fromJson) {
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return fromJson(Map<String, dynamic>.from(api.data as Map));
  }
}
