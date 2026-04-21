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
