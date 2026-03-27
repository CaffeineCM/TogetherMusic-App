/// 已登录用户信息
class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? nickname;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.nickname,
    this.avatarUrl,
    this.createdAt,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : username;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

/// 用户模型（别名，用于兼容）
class User {
  final int id;
  final String username;
  final String email;
  final String? nickname;
  final String? avatarUrl;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.nickname,
    this.avatarUrl,
    required this.createdAt,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : username;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
