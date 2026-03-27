import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart' as stomp;
import '../models/message.dart';
import 'api_client.dart';

/// STOMP WebSocket 配置
class StompServiceConfig {
  /// WebSocket 服务器地址
  static const String wsUrl = 'ws://localhost:8080/server/websocket';

  /// SockJS 备用地址
  static const String sockJsUrl = 'http://localhost:8080/server';

  /// 重连延迟（毫秒）
  static const int reconnectDelay = 5000;

  /// 心跳间隔（毫秒）
  static const int heartbeatInterval = 10000;
}

/// WebSocket 连接状态
enum StompConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// STOMP WebSocket 服务封装
/// 管理 WebSocket 连接、订阅、消息发送
class StompService {
  stomp.StompClient? _client;
  StompConnectionState _state = StompConnectionState.disconnected;

  // 订阅管理
  final Map<String, stomp.StompUnsubscribe> _subscriptions = {};
  final StreamController<Message> _messageController =
      StreamController<Message>.broadcast();

  // 连接状态流
  final StreamController<StompConnectionState> _stateController =
      StreamController<StompConnectionState>.broadcast();

  // 当前房间ID
  String? _currentHouseId;
  String? _currentRoomPassword;
  bool _isRejoiningRoom = false;

  // 单例模式
  static final StompService _instance = StompService._internal();
  factory StompService() => _instance;
  StompService._internal();

  // ========== 公开属性 ==========

  /// 消息流，UI 层订阅此流接收消息
  Stream<Message> get messageStream => _messageController.stream;

  /// 连接状态流
  Stream<StompConnectionState> get stateStream => _stateController.stream;

  /// 当前连接状态
  StompConnectionState get state => _state;

  /// 是否已连接
  bool get isConnected => _state == StompConnectionState.connected;

  /// 当前房间ID
  String? get currentHouseId => _currentHouseId;

  // ========== 连接管理 ==========

  /// 连接到 WebSocket 服务器
  void connect() {
    if (_state == StompConnectionState.connecting ||
        _state == StompConnectionState.connected) {
      print('[STOMP] Already connected or connecting');
      return;
    }

    _updateState(StompConnectionState.connecting);

    final token = apiClient.token;
    final url = token != null
        ? '${StompServiceConfig.wsUrl}?token=$token'
        : StompServiceConfig.wsUrl;

    _client = stomp.StompClient(
      config: stomp.StompConfig(
        url: url,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onError,
        onWebSocketError: _onWebSocketError,
        reconnectDelay: const Duration(
          milliseconds: StompServiceConfig.reconnectDelay,
        ),
        heartbeatIncoming: const Duration(
          milliseconds: StompServiceConfig.heartbeatInterval,
        ),
        heartbeatOutgoing: const Duration(
          milliseconds: StompServiceConfig.heartbeatInterval,
        ),
      ),
    );

    _client!.activate();
    print('[STOMP] Connecting to $url');
  }

  /// 断开连接
  void disconnect() {
    _unsubscribeAll();
    _client?.deactivate();
    _client = null;
    _updateState(StompConnectionState.disconnected);
    print('[STOMP] Disconnected');
  }

  /// 重新连接
  void reconnect() {
    disconnect();
    Future.delayed(const Duration(seconds: 1), connect);
  }

  // ========== 房间相关 ==========

  /// 加入房间（订阅房间广播主题）
  void joinRoom(String houseId, {bool forceResubscribe = false}) {
    if (!forceResubscribe && _currentHouseId == houseId) return;

    // 离开之前的房间
    if (_currentHouseId != null && _currentHouseId != houseId) {
      leaveRoom();
    }

    _currentHouseId = houseId;

    // 订阅房间广播主题 /topic/{houseId}
    _subscribe('/topic/$houseId', (frame) {
      _handleMessage(frame, houseId);
    });

    print('[STOMP] Joined room: $houseId');
  }

  /// 离开房间
  void leaveRoom() {
    if (_currentHouseId == null) return;

    // 取消房间相关订阅
    _unsubscribe('/topic/$_currentHouseId');
    print('[STOMP] Left room: $_currentHouseId');
    _currentHouseId = null;
    _currentRoomPassword = null;
    _isRejoiningRoom = false;
  }

  // ========== 消息发送 ==========

  /// 发送消息到指定目的地
  void send(String destination, {Map<String, dynamic>? body}) {
    if (!isConnected) {
      print('[STOMP] Cannot send, not connected');
      return;
    }

    final resolvedDestination = destination.startsWith('/app/')
        ? destination
        : '/app$destination';
    final jsonBody = body != null ? jsonEncode(body) : '';
    _client!.send(
      destination: resolvedDestination,
      body: jsonBody,
      headers: {'content-type': 'application/json'},
    );
    print('[STOMP] Sent to $resolvedDestination: $jsonBody');
  }

  /// 创建房间
  void createRoom({
    required String name,
    String? desc,
    String? password,
    bool keepRoom = false,
  }) {
    _currentRoomPassword = password;
    send(
      '/house/add',
      body: {
        'name': name,
        if (desc != null) 'desc': desc,
        if (password != null) 'password': password,
        'keepRoom': keepRoom,
      },
    );
  }

  /// 进入房间
  void enterRoom({required String houseId, String? password}) {
    _currentRoomPassword = password;
    send(
      '/house/enter',
      body: {'houseId': houseId, if (password != null) 'password': password},
    );
  }

  /// 搜索房间
  void searchRooms() {
    send('/house/search');
  }

  /// 获取房间用户列表
  void getRoomUsers() {
    send('/house/houseuser');
  }

  /// 点歌
  void pickMusic({
    String? id,
    String? name,
    String source = 'wy',
    String quality = '320k',
  }) {
    if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
      return;
    }

    send(
      '/music/pick',
      body: {
        if (id != null && id.isNotEmpty) 'id': id,
        if (name != null && name.isNotEmpty) 'name': name,
        'source': source,
        'quality': quality,
      },
    );
  }

  /// 发送聊天消息
  void sendChat(String content) {
    send('/chat/send', body: {'content': content});
  }

  /// 投票切歌
  void voteSkip() {
    send('/music/skip/vote');
  }

  void pausePlayback() {
    send('/music/playback/pause');
  }

  void resumePlayback() {
    send('/music/playback/resume');
  }

  void seekPlayback(int positionMs) {
    send('/music/playback/seek/$positionMs');
  }

  /// 点赞歌曲
  void likeMusic(String musicId) {
    send('/music/good/$musicId');
  }

  /// 删除待播歌曲（非管理员仅可删自己点的）
  void deleteMusic(String musicId) {
    send('/music/delete', body: {'id': musicId});
  }

  /// 置顶歌曲（管理员）
  void topMusic(String musicId) {
    send('/music/top', body: {'id': musicId});
  }

  /// 清空播放列表（管理员）
  void clearPickList() {
    send('/music/clear');
  }

  void grantAdmin(String sessionId) {
    send('/user/admin/$sessionId');
  }

  void revokeAdmin(String sessionId) {
    send('/user/member/$sessionId');
  }

  void kickUser(String sessionId) {
    send('/user/kick/$sessionId');
  }

  void blackUser(String sessionId) {
    send('/user/black/$sessionId');
  }

  void showBlackUsers() {
    send('/user/blacklist');
  }

  void unblackUser(String targetId) {
    send('/user/unblack/$targetId');
  }

  // ========== 内部方法 ==========

  void _onConnect(stomp.StompFrame frame) {
    _updateState(StompConnectionState.connected);
    print('[STOMP] Connected');
    _subscriptions.clear();

    _subscribe('/user/queue/reply', (frame) {
      _handleMessage(frame, _currentHouseId ?? '');
    });

    // 如果之前有房间，重新订阅
    if (_currentHouseId != null) {
      joinRoom(_currentHouseId!, forceResubscribe: true);
      _reEnterCurrentRoom();
    }
  }

  void _onDisconnect(stomp.StompFrame frame) {
    _subscriptions.clear();
    _isRejoiningRoom = false;
    if (_state != StompConnectionState.disconnected) {
      _updateState(StompConnectionState.reconnecting);
      print('[STOMP] Disconnected, will reconnect...');
    }
  }

  void _onError(stomp.StompFrame frame) {
    _subscriptions.clear();
    _isRejoiningRoom = false;
    _updateState(StompConnectionState.error);
    print('[STOMP] Error: ${frame.body}');
  }

  void _onWebSocketError(dynamic error) {
    _subscriptions.clear();
    _isRejoiningRoom = false;
    _updateState(StompConnectionState.error);
    print('[STOMP] WebSocket Error: $error');
  }

  void _updateState(StompConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _subscribe(
    String destination,
    void Function(stomp.StompFrame) callback,
  ) {
    if (_client == null || !isConnected) return;

    final unsubscribe = _client!.subscribe(
      destination: destination,
      callback: callback,
    );

    _subscriptions[destination] = unsubscribe;
    print('[STOMP] Subscribed to $destination');
  }

  void _unsubscribe(String destination) {
    final unsubscribe = _subscriptions.remove(destination);
    unsubscribe?.call();
    print('[STOMP] Unsubscribed from $destination');
  }

  void _unsubscribeAll() {
    for (final unsubscribe in _subscriptions.values) {
      unsubscribe();
    }
    _subscriptions.clear();
  }

  void _handleMessage(stomp.StompFrame frame, String houseId) {
    try {
      if (frame.body == null) return;

      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final message = Message.fromJson(data, houseId);
      if (message.type == MessageType.enterHouse) {
        _isRejoiningRoom = false;
      }

      _messageController.add(message);
      print('[STOMP] Received ${message.type}: ${message.data}');
    } catch (e) {
      print('[STOMP] Error parsing message: $e');
    }
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }

  void _reEnterCurrentRoom() {
    if (_currentHouseId == null || _isRejoiningRoom || !isConnected) {
      return;
    }

    _isRejoiningRoom = true;
    send(
      '/house/enter',
      body: {
        'houseId': _currentHouseId,
        if (_currentRoomPassword != null) 'password': _currentRoomPassword,
      },
    );
    print('[STOMP] Re-enter room after reconnect: $_currentHouseId');
  }
}

/// 全局 STOMP 服务实例
final stompService = StompService();
