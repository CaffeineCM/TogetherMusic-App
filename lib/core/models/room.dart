/// 房间摘要，用于房间列表
class RoomSummary {
  final String id;
  final String name;
  final String? desc;
  final bool needPwd;
  final int onlineCount;

  const RoomSummary({
    required this.id,
    required this.name,
    this.desc,
    required this.needPwd,
    required this.onlineCount,
  });

  /// 在线人数（别名，用于兼容）
  int get population => onlineCount;

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      desc: json['desc'] as String?,
      needPwd: json['needPwd'] as bool? ?? false,
      onlineCount: json['onlineCount'] as int? ?? json['population'] as int? ?? 0,
    );
  }
}

/// 在线用户
class SessionUser {
  final String sessionId;
  final String displayName;
  final String role;

  const SessionUser({
    required this.sessionId,
    required this.displayName,
    required this.role,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      sessionId: json['sessionId'] as String,
      displayName: json['displayName'] as String? ?? '匿名用户',
      role: json['role'] as String? ?? 'default',
    );
  }

  bool get isAdmin => role == 'admin' || role == 'root';
}

/// 房间详情
class Room {
  final String id;
  final String name;
  final String? desc;
  final bool needPwd;
  final int onlineCount;
  final String creatorId;

  const Room({
    required this.id,
    required this.name,
    this.desc,
    required this.needPwd,
    required this.onlineCount,
    required this.creatorId,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      desc: json['desc'] as String?,
      needPwd: json['needPwd'] as bool? ?? false,
      onlineCount: json['onlineCount'] as int? ?? 0,
      creatorId: json['creatorId'] as String? ?? '',
    );
  }
}
