/// 应用全局常量
class AppConstants {
  AppConstants._();

  // API 基础地址（开发环境）
  static const String baseUrl = 'http://localhost:8080';
  static const String wsUrl = 'ws://localhost:8080/server';

  // 本地存储 Key
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String usernameKey = 'username';
  static const String nicknameKey = 'nickname';

  // 音乐源
  static const List<Map<String, String>> musicSources = [
    {'code': 'wy', 'name': '网易云'},
    {'code': 'qq', 'name': 'QQ音乐'},
    {'code': 'kg', 'name': '酷狗'},
    {'code': 'upload', 'name': '我的上传'},
  ];

  // 音质选项
  static const List<Map<String, String>> qualities = [
    {'code': '128k', 'name': '标准'},
    {'code': '320k', 'name': '高品质'},
    {'code': 'flac', 'name': '无损'},
  ];
}
