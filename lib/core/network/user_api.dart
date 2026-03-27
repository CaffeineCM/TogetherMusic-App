import '../models/user.dart';
import 'api_client.dart';

/// 用户相关 API
class UserApi {
  /// 获取当前用户资料
  /// GET /user/profile
  static Future<User?> getProfile() async {
    final response = await apiClient.get(
      '/user/profile',
      fromData: (data) => User.fromJson(data as Map<String, dynamic>),
    );

    return response.isSuccess ? response.data : null;
  }

  /// 更新用户资料
  /// PUT /user/profile
  static Future<bool> updateProfile({
    String? nickname,
    String? avatarUrl,
  }) async {
    final response = await apiClient.put(
      '/user/profile',
      data: {
        if (nickname != null) 'nickname': nickname,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );

    return response.isSuccess;
  }
}
