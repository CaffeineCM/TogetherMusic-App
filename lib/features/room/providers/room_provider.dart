import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/models/music.dart';
import '../../../core/models/playback_snapshot.dart';
import '../../../core/models/room.dart';
import '../../../core/network/room_api.dart';
import '../../../core/network/stomp_service.dart';

/// 房间状态
class RoomState {
  final List<RoomSummary> roomList;
  final Room? currentRoom;
  final Music? currentPlaying;
  final PlaybackSnapshot? playbackSnapshot;
  final List<Music> pickList;
  final List<OnlineUser> onlineUsers;
  final List<String> blacklistedUsers;
  final List<RoomFeedItem> feedItems;
  final bool isLoading;
  final String? error;
  final bool isConnected;

  const RoomState({
    this.roomList = const [],
    this.currentRoom,
    this.currentPlaying,
    this.playbackSnapshot,
    this.pickList = const [],
    this.onlineUsers = const [],
    this.blacklistedUsers = const [],
    this.feedItems = const [],
    this.isLoading = false,
    this.error,
    this.isConnected = false,
  });

  RoomState copyWith({
    List<RoomSummary>? roomList,
    Object? currentRoom = _roomUnchanged,
    Object? currentPlaying = _musicUnchanged,
    Object? playbackSnapshot = _playbackUnchanged,
    List<Music>? pickList,
    List<OnlineUser>? onlineUsers,
    List<String>? blacklistedUsers,
    List<RoomFeedItem>? feedItems,
    bool? isLoading,
    String? error,
    bool? isConnected,
  }) {
    return RoomState(
      roomList: roomList ?? this.roomList,
      currentRoom: identical(currentRoom, _roomUnchanged)
          ? this.currentRoom
          : currentRoom as Room?,
      currentPlaying: identical(currentPlaying, _musicUnchanged)
          ? this.currentPlaying
          : currentPlaying as Music?,
      playbackSnapshot: identical(playbackSnapshot, _playbackUnchanged)
          ? this.playbackSnapshot
          : playbackSnapshot as PlaybackSnapshot?,
      pickList: pickList ?? this.pickList,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      blacklistedUsers: blacklistedUsers ?? this.blacklistedUsers,
      feedItems: feedItems ?? this.feedItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  /// 当前房间ID
  String? get currentHouseId => currentRoom?.id;

  /// 当前房间人数
  int get onlineCount => onlineUsers.length;

  /// 是否在某个房间中
  bool get isInRoom => currentRoom != null;
}

const Object _roomUnchanged = Object();
const Object _musicUnchanged = Object();
const Object _playbackUnchanged = Object();

/// 房间状态 Notifier
class RoomNotifier extends StateNotifier<RoomState> {
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<StompConnectionState>? _connectionSubscription;
  Timer? _pendingActionTimer;

  RoomNotifier() : super(const RoomState()) {
    _init();
  }

  void _init() {
    // 监听 WebSocket 消息
    _messageSubscription = stompService.messageStream.listen(_handleMessage);

    // 监听连接状态
    _connectionSubscription = stompService.stateStream.listen((
      connectionState,
    ) {
      final isConnected = connectionState == StompConnectionState.connected;
      state = state.copyWith(isConnected: isConnected);
    });

    // 连接 WebSocket
    stompService.connect();
  }

  /// 处理 WebSocket 消息
  void _handleMessage(Message message) {
    switch (message.type) {
      case MessageType.addHouse:
      case MessageType.enterHouse:
      case MessageType.notice:
        _clearPendingActionTimer();
        break;
      default:
        break;
    }

    switch (message.type) {
      case MessageType.pick:
        final pickList = message.pickListData;
        if (pickList != null) {
          _appendPickFeed(state.pickList, pickList);
          state = state.copyWith(pickList: pickList);
        }
        break;

      case MessageType.online:
        final users = message.onlineUsersData;
        if (users != null) {
          final currentRoom = state.currentRoom;
          final currentSessionId = currentRoom?.currentSessionId;
          OnlineUser? self;
          if (currentSessionId != null && currentSessionId.isNotEmpty) {
            for (final user in users) {
              if (user.sessionId == currentSessionId) {
                self = user;
                break;
              }
            }
          }
          state = state.copyWith(
            onlineUsers: users,
            currentRoom: currentRoom == null
                ? currentRoom
                : currentRoom.copyWith(
                    onlineCount: users.length,
                    currentUserRole: self?.role ?? currentRoom.currentUserRole,
                  ),
          );
        }
        break;

      case MessageType.blacklist:
        final blacklist = message.blacklistData;
        if (blacklist != null) {
          state = state.copyWith(blacklistedUsers: blacklist);
        }
        break;

      case MessageType.addHouse:
        // 创建房间成功，更新当前房间
        if (message.data != null && message.code == 200) {
          final roomData = message.data as Map<String, dynamic>;
          final room = Room.fromJson(roomData);
          _upsertRoomSummary(
            RoomSummary(
              id: room.id,
              name: room.name,
              desc: room.desc,
              needPwd: room.needPwd,
              onlineCount: room.onlineCount > 0 ? room.onlineCount : 1,
            ),
          );
          _appendSystemFeed('房间创建成功：${room.name}');
          _enterRoomInternal(room);
        } else {
          state = state.copyWith(
            isLoading: false,
            error: message.message ?? '创建房间失败',
          );
        }
        break;

      case MessageType.enterHouse:
        // 进入房间成功
        if (message.data != null && message.code == 200) {
          final roomData = message.data as Map<String, dynamic>;
          final room = Room.fromJson(roomData);
          _appendSystemFeed('已进入房间：${room.name}');
          _enterRoomInternal(room);
        } else {
          state = state.copyWith(
            isLoading: false,
            error: message.message ?? '进入房间失败',
          );
        }
        break;

      case MessageType.searchHouse:
        // 房间列表
        if (message.data != null) {
          final list = (message.data as List<dynamic>)
              .map((item) => RoomSummary.fromJson(item as Map<String, dynamic>))
              .toList();
          state = state.copyWith(roomList: list);
        }
        break;

      case MessageType.notice:
        // 系统通知，可能包含错误信息
        final notice = message.noticeText;
        if (notice != null && notice.isNotEmpty) {
          _appendSystemFeed(notice);
        }
        if (message.code != 200) {
          state = state.copyWith(isLoading: false, error: notice);
        }
        break;

      case MessageType.kick:
        final kickMessage = message.message ?? '你已被移出房间';
        stompService.leaveRoom();
        state = state.copyWith(
          currentRoom: null,
          currentPlaying: null,
          playbackSnapshot: null,
          pickList: [],
          onlineUsers: [],
          feedItems: [],
          error: kickMessage,
        );
        break;

      case MessageType.chat:
        final chat = message.chatData;
        if (chat != null) {
          _appendChatFeed(chat);
        }
        break;

      case MessageType.music:
        final music = message.musicData;
        state = state.copyWith(currentPlaying: music);
        if (music != null) {
          _appendSystemFeed('正在播放：${music.name} - ${music.artist ?? '未知艺术家'}');
        }
        break;

      case MessageType.playback:
        final playback = message.playbackData;
        if (playback != null) {
          state = state.copyWith(
            playbackSnapshot: playback,
            currentPlaying: playback.music,
          );
        }
        break;

      case MessageType.volume:
        if (message.data != null) {
          _appendSystemFeed('房间音量已调整为 ${message.data}');
        }
        break;

      default:
        break;
    }
  }

  /// 获取房间列表
  Future<void> fetchRoomList() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 通过 REST API 获取
      final rooms = await RoomApi.getRoomList();
      state = state.copyWith(roomList: rooms ?? [], isLoading: false);

      // 同时通过 WebSocket 获取（实时数据）
      stompService.searchRooms();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '获取房间列表失败: $e');
    }
  }

  /// 创建房间
  void createRoom({
    required String name,
    String? desc,
    String? password,
    bool keepRoom = false,
  }) {
    if (!state.isConnected) {
      state = state.copyWith(error: '未连接到服务器');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    _startPendingActionTimer('创建房间超时，请检查后端日志');
    stompService.createRoom(
      name: name,
      desc: desc,
      password: password,
      keepRoom: keepRoom,
    );
  }

  /// 进入房间
  void enterRoom({required String houseId, String? password}) {
    if (!state.isConnected) {
      state = state.copyWith(error: '未连接到服务器');
      return;
    }

    // 如果已经在其他房间，先离开
    if (state.isInRoom && state.currentHouseId != houseId) {
      leaveRoom();
    }

    state = state.copyWith(isLoading: true, error: null);
    _startPendingActionTimer('进入房间超时，请检查后端日志');
    stompService.enterRoom(houseId: houseId, password: password);
  }

  /// 内部方法：进入房间后的处理
  void _enterRoomInternal(Room room) {
    state = state.copyWith(
      currentRoom: room,
      currentPlaying: null,
      playbackSnapshot: null,
      isLoading: false,
      pickList: [],
      onlineUsers: [],
      blacklistedUsers: [],
      feedItems: [],
    );

    // 订阅房间消息
    stompService.joinRoom(room.id);

    // 获取房间用户列表
    stompService.getRoomUsers();
    unawaited(_syncCurrentPlaying(room.id));
    unawaited(_syncPlaybackSnapshot(room.id));
  }

  /// 离开房间
  void leaveRoom() {
    if (!state.isInRoom) return;

    stompService.leaveRoom();
    state = state.copyWith(
      currentRoom: null,
      currentPlaying: null,
      playbackSnapshot: null,
      pickList: [],
      onlineUsers: [],
      blacklistedUsers: [],
      feedItems: [],
    );
  }

  void _upsertRoomSummary(RoomSummary summary) {
    final updated = [...state.roomList];
    final index = updated.indexWhere((room) => room.id == summary.id);
    if (index >= 0) {
      updated[index] = summary;
    } else {
      updated.insert(0, summary);
    }
    state = state.copyWith(roomList: updated);
  }

  void _startPendingActionTimer(String timeoutMessage) {
    _clearPendingActionTimer();
    _pendingActionTimer = Timer(const Duration(seconds: 8), () {
      state = state.copyWith(isLoading: false, error: timeoutMessage);
    });
  }

  void _clearPendingActionTimer() {
    _pendingActionTimer?.cancel();
    _pendingActionTimer = null;
  }

  /// 点歌
  void pickMusic({
    String? keyword,
    String? musicId,
    String source = 'wy',
    String quality = '320k',
  }) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }

    if ((musicId == null || musicId.isEmpty) &&
        (keyword == null || keyword.trim().isEmpty)) {
      state = state.copyWith(error: '歌曲信息无效');
      return;
    }

    stompService.pickMusic(
      id: musicId,
      name: keyword?.trim(),
      source: source,
      quality: quality,
    );
  }

  /// 发送聊天消息
  void sendChat(String content) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }

    if (content.trim().isEmpty) return;

    stompService.sendChat(content.trim());
  }

  /// 投票切歌
  void voteSkip() {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }

    stompService.voteSkip();
  }

  /// 点赞歌曲
  void likeMusic(String musicId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }

    stompService.likeMusic(musicId);
  }

  /// 删除待播歌曲（非管理员仅可删自己点的）
  void deleteMusic(String musicId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.deleteMusic(musicId);
  }

  /// 置顶歌曲（管理员）
  void topMusic(String musicId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.topMusic(musicId);
  }

  /// 清空播放列表（管理员）
  void clearPickList() {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.clearPickList();
  }

  void grantAdmin(String sessionId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.grantAdmin(sessionId);
  }

  void revokeAdmin(String sessionId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.revokeAdmin(sessionId);
  }

  void kickUser(String sessionId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.kickUser(sessionId);
  }

  void blackUser(String sessionId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.blackUser(sessionId);
  }

  void showBlackUsers() {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.showBlackUsers();
  }

  void unblackUser(String targetId) {
    if (!state.isInRoom) {
      state = state.copyWith(error: '请先进入房间');
      return;
    }
    stompService.unblackUser(targetId);
  }

  /// 重新连接 WebSocket
  void reconnect() {
    stompService.reconnect();
  }

  Future<void> _syncCurrentPlaying(String houseId) async {
    final currentPlaying = await RoomApi.getCurrentPlaying(houseId);
    if (state.currentHouseId != houseId) {
      return;
    }
    state = state.copyWith(currentPlaying: currentPlaying);
  }

  Future<void> _syncPlaybackSnapshot(String houseId) async {
    final snapshot = await RoomApi.getPlaybackSnapshot(houseId);
    if (state.currentHouseId != houseId) {
      return;
    }
    state = state.copyWith(
      playbackSnapshot: snapshot,
      currentPlaying: snapshot?.music,
    );
  }

  void _appendChatFeed(ChatMessage chat) {
    _appendFeed(
      RoomFeedItem.chat(
        sender: chat.sender,
        content: chat.content,
        sessionId: chat.sessionId,
        timestamp: chat.timestamp,
      ),
    );
  }

  void _appendSystemFeed(String content) {
    _appendFeed(RoomFeedItem.system(content: content));
  }

  void _appendPickFeed(List<Music> previous, List<Music> current) {
    final previousIds = previous.map((music) => music.id).toSet();
    final added = current
        .where((music) => !previousIds.contains(music.id))
        .toList();
    for (final music in added) {
      _appendSystemFeed('已加入播放列表：${music.name} - ${music.artist ?? '未知艺术家'}');
    }
  }

  void _appendFeed(RoomFeedItem item) {
    final next = [...state.feedItems, item];
    if (next.length > 150) {
      next.removeRange(0, next.length - 150);
    }
    state = state.copyWith(feedItems: next);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _clearPendingActionTimer();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    stompService.dispose();
    super.dispose();
  }
}

/// RoomProvider 全局实例
final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier();
});

class RoomFeedItem {
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isSystem;
  final String? sessionId;

  const RoomFeedItem({
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isSystem,
    this.sessionId,
  });

  factory RoomFeedItem.chat({
    required String sender,
    required String content,
    required DateTime timestamp,
    String? sessionId,
  }) {
    return RoomFeedItem(
      sender: sender,
      content: content,
      timestamp: timestamp,
      isSystem: false,
      sessionId: sessionId,
    );
  }

  factory RoomFeedItem.system({required String content}) {
    return RoomFeedItem(
      sender: '系统',
      content: content,
      timestamp: DateTime.now(),
      isSystem: true,
    );
  }
}
