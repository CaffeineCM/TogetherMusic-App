/// 统一 API 响应体，对应后端 `Response<T>`
class ApiResponse<T> {
  final int code;
  final String? message;
  final T? data;
  final String? type;

  const ApiResponse({required this.code, this.message, this.data, this.type});

  bool get isSuccess => code == 200;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String?,
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
      type: json['type'] as String?,
    );
  }
}
