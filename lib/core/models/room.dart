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
      onlineCount:
          json['onlineCount'] as int? ?? json['population'] as int? ?? 0,
    );
  }
}

/// 在线用户
class SessionUser {
  final String sessionId;
  final String displayName;
  final String role;
  final int? registeredUserId;

  const SessionUser({
    required this.sessionId,
    required this.displayName,
    required this.role,
    this.registeredUserId,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      sessionId: json['sessionId'] as String,
      displayName: json['displayName'] as String? ?? '匿名用户',
      role: json['role'] as String? ?? 'member',
      registeredUserId: json['registeredUserId'] as int?,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isManager => isOwner || isAdmin;
  bool get isGuest => registeredUserId == null;
}

/// 房间详情
class Room {
  final String id;
  final String name;
  final String? desc;
  final bool needPwd;
  final int onlineCount;
  final String creatorSessionId;
  final int? creatorUserId;
  final String currentSessionId;
  final String currentUserRole;

  const Room({
    required this.id,
    required this.name,
    this.desc,
    required this.needPwd,
    required this.onlineCount,
    required this.creatorSessionId,
    required this.creatorUserId,
    required this.currentSessionId,
    required this.currentUserRole,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      desc: json['desc'] as String?,
      needPwd: json['needPwd'] as bool? ?? false,
      onlineCount: json['onlineCount'] as int? ?? 0,
      creatorSessionId: json['creatorSessionId'] as String? ?? '',
      creatorUserId: json['creatorUserId'] as int?,
      currentSessionId: json['currentSessionId'] as String? ?? '',
      currentUserRole: json['currentUserRole'] as String? ?? 'member',
    );
  }

  Room copyWith({
    int? onlineCount,
    String? currentUserRole,
    String? currentSessionId,
  }) {
    return Room(
      id: id,
      name: name,
      desc: desc,
      needPwd: needPwd,
      onlineCount: onlineCount ?? this.onlineCount,
      creatorSessionId: creatorSessionId,
      creatorUserId: creatorUserId,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
    );
  }

  bool get isOwner => currentUserRole == 'owner';
  bool get isAdmin => currentUserRole == 'admin';
  bool get isManager => isOwner || isAdmin;
}
