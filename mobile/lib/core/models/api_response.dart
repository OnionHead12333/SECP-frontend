import '../util/api_user_message.dart';

/// 与后端 [ApiResponse] JSON 结构一致。
class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final T? data;

  bool get isSuccess => code == 0;

  /// 展示给用户（已过滤 SQL/JDBC 等技术细节）；失败分支请用此字段抛出或提示。
  String get displayMessage => userFacingApiMessage(message);

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Object? json)? dataFromJson,
  ) {
    final rawCode = json['code'];
    int code = -1;
    if (rawCode is int) {
      code = rawCode;
    } else if (rawCode is num) {
      code = rawCode.toInt();
    } else if (rawCode != null) {
      code = int.tryParse('$rawCode') ?? -1;
    }
    return ApiResponse<T>(
      code: code,
      message: json['message'] as String? ?? '',
      data: dataFromJson != null ? dataFromJson(json['data']) : json['data'] as T?,
    );
  }
}
