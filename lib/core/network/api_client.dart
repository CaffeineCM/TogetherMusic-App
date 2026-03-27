import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';

/// API 客户端配置
class ApiConfig {
  /// 后端 API 基础 URL
  static const String baseUrl = 'http://localhost:8080';

  /// API 版本前缀
  static const String apiPrefix = '/api/v1';

  /// 连接超时时间（毫秒）
  static const int connectTimeout = 30000;

  /// 接收超时时间（毫秒）
  static const int receiveTimeout = 30000;

  /// 发送超时时间（毫秒）
  static const int sendTimeout = 30000;
}

/// HTTP 客户端封装（基于 Dio）
/// 自动处理 Token 附加、响应解析、错误处理
class ApiClient {
  late final Dio _dio;
  String? _token;
  final Completer<void> _readyCompleter = Completer<void>();

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
    _loadToken();
  }

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 自动附加 Authorization Token
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          print('[API Request] ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('[API Response] ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('[API Error] ${error.response?.statusCode} ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// 从本地存储加载 Token
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  Future<void> get ready => _readyCompleter.future;

  /// 设置 Token（登录成功后调用）
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// 清除 Token（登出时调用）
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// 获取当前 Token
  String? get token => _token;

  /// 是否已登录
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  // ========== HTTP 方法封装 ==========

  /// GET 请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromData,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      return _parseResponse(response, fromData);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// POST 请求
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromData,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _parseResponse(response, fromData);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// PUT 请求
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromData,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
      );
      return _parseResponse(response, fromData);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE 请求
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromData,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
      );
      return _parseResponse(response, fromData);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 上传文件（multipart/form-data）
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
    T Function(dynamic)? fromData,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        ...?extraData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return _parseResponse(response, fromData);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // ========== 内部方法 ==========

  /// 解析响应
  ApiResponse<T> _parseResponse<T>(
    Response response,
    T Function(dynamic)? fromData,
  ) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        fromData,
      );
    } else {
      return ApiResponse(
        code: response.statusCode ?? -1,
        message: 'HTTP ${response.statusCode}',
        data: null,
        type: null,
      );
    }
  }

  /// 处理错误
  ApiResponse<T> _handleError<T>(DioException error) {
    String message;
    int code;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '连接超时，请检查网络';
        code = -1;
        break;
      case DioExceptionType.connectionError:
        message = '网络连接失败，请检查网络';
        code = -1;
        break;
      case DioExceptionType.badResponse:
        code = error.response?.statusCode ?? -1;
        message = error.response?.data?['message'] ?? '请求失败 ($code)';
        break;
      default:
        message = error.message ?? '未知错误';
        code = -1;
    }

    return ApiResponse(
      code: code,
      message: message,
      data: null,
      type: null,
    );
  }
}

/// 全局 API 客户端实例
final apiClient = ApiClient();
