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
    return ApiResponse<T>(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: dataFromJson != null ? dataFromJson(json['data']) : json['data'] as T?,
    );
  }
}
