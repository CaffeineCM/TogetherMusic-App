import 'music.dart';
import 'playback_snapshot.dart';

/// WebSocket 消息类型
enum MessageType {
  music, // 当前播放歌曲
  pick, // 点歌列表更新
  chat, // 聊天消息
  notice, // 系统通知
  online, // 在线人数变更
  announcement, // 房间公告
  goodModel, // 点赞模式开关
  volume, // 音量变更
  playback, // 播放状态快照
  addHouse, // 创建房间结果
  enterHouse, // 进入房间结果
  searchHouse, // 房间列表
  authAdmin, // 管理员鉴权结果
  kick, // 被踢出通知
  unknown, // 未知类型
}

/// WebSocket 消息
class Message {
  final MessageType type;
  final dynamic data;
  final String? message;
  final int code;
  final String houseId;
  final DateTime timestamp;

  Message({
    required this.type,
    this.data,
    this.message,
    this.code = 200,
    required this.houseId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json, String houseId) {
    final typeStr = json['type'] as String? ?? '';
    final type = _parseMessageType(typeStr);
    final payload = _unwrapPayload(json['data']);

    return Message(
      type: type,
      data: payload?.data ?? json['data'],
      message: payload?.message ?? json['message'] as String?,
      code: payload?.code ?? json['code'] as int? ?? 200,
      houseId: houseId,
    );
  }

  static _WsPayload? _unwrapPayload(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      return null;
    }

    final hasEnvelope =
        rawData.containsKey('code') &&
        rawData.containsKey('message') &&
        rawData.containsKey('data');
    if (!hasEnvelope) {
      return null;
    }

    return _WsPayload(
      code: rawData['code'] as int? ?? 200,
      message: rawData['message'] as String?,
      data: rawData['data'],
    );
  }

  /// 获取音乐数据（当 type 为 music 时）
  Music? get musicData {
    if (type == MessageType.music && data != null) {
      try {
        return Music.fromJson(data as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取音乐列表（当 type 为 pick 时）
  List<Music>? get pickListData {
    if (type == MessageType.pick && data != null) {
      try {
        final list = data as List<dynamic>;
        return list
            .map((item) => Music.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取聊天消息内容（当 type 为 chat 时）
  ChatMessage? get chatData {
    if (type == MessageType.chat && data != null) {
      try {
        return ChatMessage.fromJson(data as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取在线用户列表（当 type 为 online 时）
  List<OnlineUser>? get onlineUsersData {
    if (type == MessageType.online && data != null) {
      try {
        final list = data as List<dynamic>;
        return list
            .map((item) => OnlineUser.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  PlaybackSnapshot? get playbackData {
    if (type == MessageType.playback && data != null) {
      try {
        return PlaybackSnapshot.fromJson(data as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取通知文本（当 type 为 notice 时）
  String? get noticeText {
    if (type == MessageType.notice) {
      if (data is String) {
        return data as String;
      }
      return message;
    }
    return null;
  }

  static MessageType _parseMessageType(String type) {
    switch (type.toUpperCase()) {
      case 'MUSIC':
        return MessageType.music;
      case 'PICK':
        return MessageType.pick;
      case 'CHAT':
        return MessageType.chat;
      case 'NOTICE':
        return MessageType.notice;
      case 'ONLINE':
        return MessageType.online;
      case 'ANNOUNCEMENT':
        return MessageType.announcement;
      case 'GOODMODEL':
        return MessageType.goodModel;
      case 'VOLUMN':
      case 'VOLUME':
        return MessageType.volume;
      case 'PLAYBACK':
        return MessageType.playback;
      case 'ADD_HOUSE':
        return MessageType.addHouse;
      case 'ENTER_HOUSE':
        return MessageType.enterHouse;
      case 'SEARCH_HOUSE':
        return MessageType.searchHouse;
      case 'AUTH_ADMIN':
        return MessageType.authAdmin;
      case 'KICK':
        return MessageType.kick;
      default:
        return MessageType.unknown;
    }
  }
}

class _WsPayload {
  final int code;
  final String? message;
  final dynamic data;

  const _WsPayload({
    required this.code,
    required this.message,
    required this.data,
  });
}

/// 聊天消息
class ChatMessage {
  final String sessionId;
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sessionId: json['sessionId'] as String? ?? '',
      sender:
          json['displayName'] as String? ?? json['sender'] as String? ?? '未知用户',
      content: json['content'] as String? ?? '',
      timestamp: json['sendTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['sendTime'] as int)
          : json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// 在线用户
class OnlineUser {
  final String sessionId;
  final String displayName;
  final String? role;
  final String? remoteAddress;
  final int? registeredUserId;

  OnlineUser({
    required this.sessionId,
    required this.displayName,
    this.role,
    this.remoteAddress,
    this.registeredUserId,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      sessionId: json['sessionId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '未知用户',
      role: json['role'] as String?,
      remoteAddress: json['remoteAddress'] as String?,
      registeredUserId: json['registeredUserId'] as int?,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'root';
  bool get isGuest => registeredUserId == null;
}
