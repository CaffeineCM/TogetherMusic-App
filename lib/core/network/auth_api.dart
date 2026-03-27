import '../models/user.dart';
import 'api_client.dart';

/// 认证相关 API
class AuthApi {
  /// 用户登录
  /// POST /auth/login
  static Future<LoginResult?> login(String username, String password) async {
    final response = await apiClient.post(
      '/auth/login',
      data: {
        'account': username,
        'password': password,
      },
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token != null) {
        await apiClient.setToken(token);
        return LoginResult(
          token: token,
          user: User(
            id: (data['userId'] as num?)?.toInt() ?? 0,
            username: data['username'] as String? ?? username,
            email: '',
            nickname: data['nickname'] as String?,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    return null;
  }

  /// 用户注册
  /// POST /auth/register
  static Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    return response.isSuccess;
  }

  /// 用户登出
  /// POST /auth/logout
  static Future<void> logout() async {
    await apiClient.post('/auth/logout');
    await apiClient.clearToken();
  }
}

/// 登录结果
class LoginResult {
  final String token;
  final User? user;

  LoginResult({
    required this.token,
    this.user,
  });
}
