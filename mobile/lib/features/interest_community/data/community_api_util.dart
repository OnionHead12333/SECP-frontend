import '../../../core/models/api_response.dart';

/// 兴趣社群 API 响应解析与请求体辅助（兼容 camelCase / snake_case）。
abstract final class CommunityApiUtil {
  static Map<String, dynamic> asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  static int parseCode(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? -1;
  }

  static ApiResponse<Map<String, dynamic>> parseEnvelope(Map<String, dynamic> body) {
    final data = asMap(body['data']);
    return ApiResponse<Map<String, dynamic>>(
      code: parseCode(body['code']),
      message: '${body['message'] ?? ''}',
      data: data.isEmpty ? null : data,
    );
  }

  static void throwIfFail(ApiResponse<dynamic> api) {
    if (api.code != 0) {
      throw Exception('${api.displayMessage} (code=${api.code})');
    }
  }

  /// 从 POST 发送消息等接口的 body 中取出消息对象。
  static Map<String, dynamic> requireMessageData(Map<String, dynamic>? body) {
    if (body == null) throw Exception('空响应');
    final api = parseEnvelope(body);
    throwIfFail(api);
    var data = api.data ?? asMap(body['data']);
    if (data.containsKey('message') && data['message'] is Map && !data.containsKey('kind')) {
      data = asMap(data['message']);
    }
    if (data.isEmpty) throw Exception('发送失败：服务端未返回消息内容');
    return data;
  }

  /// 文字消息 JSON（同时带 camelCase / snake_case，兼容 Jackson 命名策略）。
  static Map<String, dynamic> textMessageBody(String textContent) => {
        'kind': 'text',
        'textContent': textContent,
        'text_content': textContent,
      };
}
