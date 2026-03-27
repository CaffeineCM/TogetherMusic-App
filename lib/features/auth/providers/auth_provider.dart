import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart' as user_model;
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_api.dart';
import '../../../core/network/stomp_service.dart';
import '../../../core/network/user_api.dart';

/// 认证状态
class AuthState {
  final bool isLoggedIn;
  final user_model.User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    user_model.User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取用户ID
  int? get userId => user?.id;

  /// 获取用户名
  String? get username => user?.username;

  /// 获取昵称
  String? get nickname => user?.nickname ?? user?.username;
}

/// 认证状态 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    // 初始化时检查登录状态
    _checkLoginStatus();
  }

  /// 检查登录状态（从本地存储恢复）
  Future<void> _checkLoginStatus() async {
    await apiClient.ready;
    if (apiClient.isLoggedIn) {
      state = state.copyWith(isLoading: true);
      try {
        final user = await UserApi.getProfile();
        if (user != null) {
          state = AuthState(
            isLoggedIn: true,
            user: user,
            isLoading: false,
          );
          stompService.reconnect();
        } else {
          // Token 无效，清除
          await apiClient.clearToken();
          state = const AuthState(isLoggedIn: false);
        }
      } catch (e) {
        await apiClient.clearToken();
        state = AuthState(
          isLoggedIn: false,
          error: '恢复登录状态失败: $e',
        );
      }
    }
  }

  /// 用户登录
  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await AuthApi.login(username, password);

      if (result != null) {
        final userProfile = result.user ?? await UserApi.getProfile();

        if (userProfile == null) {
          await apiClient.clearToken();
          state = const AuthState(
            isLoggedIn: false,
            isLoading: false,
            error: '登录成功，但获取用户信息失败',
          );
          return false;
        }

        state = AuthState(
          isLoggedIn: true,
          user: userProfile,
          isLoading: false,
        );
        stompService.reconnect();
        return true;
      }

      state = AuthState(
        isLoggedIn: false,
        isLoading: false,
        error: '登录失败，请检查用户名和密码',
      );
      return false;
    } catch (e) {
      state = AuthState(
        isLoggedIn: false,
        isLoading: false,
        error: '登录出错: $e',
      );
      return false;
    }
  }

  /// 用户注册
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await AuthApi.register(
        username: username,
        email: email,
        password: password,
      );

      if (success) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = AuthState(
          isLoggedIn: false,
          isLoading: false,
          error: '注册失败',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        isLoggedIn: false,
        isLoading: false,
        error: '注册出错: $e',
      );
      return false;
    }
  }

  /// 用户登出
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await AuthApi.logout();
    } catch (e) {
      // 忽略登出错误
    } finally {
      state = const AuthState(isLoggedIn: false);
      stompService.reconnect();
    }
  }

  /// 更新用户信息
  Future<void> updateUserInfo({String? nickname, String? avatarUrl}) async {
    if (!state.isLoggedIn || state.user == null) return;

    try {
      final success = await UserApi.updateProfile(
        nickname: nickname,
        avatarUrl: avatarUrl,
      );

      if (success) {
        // 重新获取用户信息
        final updatedUserProfile = await UserApi.getProfile();
        if (updatedUserProfile != null) {
          final updatedUser = user_model.User(
            id: updatedUserProfile.id,
            username: updatedUserProfile.username,
            email: updatedUserProfile.email,
            nickname: updatedUserProfile.nickname,
            avatarUrl: updatedUserProfile.avatarUrl,
            createdAt: updatedUserProfile.createdAt ?? DateTime.now(),
          );
          state = state.copyWith(user: updatedUser);
        }
      }
    } catch (e) {
      print('更新用户信息失败: $e');
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// AuthProvider 全局实例
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
