import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/models/music.dart';
import '../../../core/network/stomp_service.dart';
import 'player_audio_bridge.dart';

/// 播放状态
enum PlaybackState {
  idle, // 空闲
  playing, // 播放中
  paused, // 暂停
  buffering, // 缓冲中
  error, // 错误
}

/// 播放器状态
class PlayerState {
  final Music? currentMusic;
  final PlaybackState playbackState;
  final double progress; // 0.0 - 1.0
  final int volume; // 0 - 100
  final bool isMuted;
  final String? error;

  // 播放进度计算相关
  final DateTime? startTime;
  final int? duration;

  const PlayerState({
    this.currentMusic,
    this.playbackState = PlaybackState.idle,
    this.progress = 0.0,
    this.volume = 80,
    this.isMuted = true,
    this.error,
    this.startTime,
    this.duration,
  });

  PlayerState copyWith({
    Music? currentMusic,
    PlaybackState? playbackState,
    double? progress,
    int? volume,
    bool? isMuted,
    String? error,
    DateTime? startTime,
    int? duration,
  }) {
    return PlayerState(
      currentMusic: currentMusic ?? this.currentMusic,
      playbackState: playbackState ?? this.playbackState,
      progress: progress ?? this.progress,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      error: error,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
    );
  }

  /// 当前播放位置（毫秒）
  int get currentPosition {
    if (startTime == null || duration == null) return 0;
    final elapsed = DateTime.now().difference(startTime!).inMilliseconds;
    return elapsed.clamp(0, duration!);
  }

  /// 格式化后的当前位置
  String get currentPositionText => _formatDuration(currentPosition);

  /// 格式化后的总时长
  String? get durationText =>
      duration != null ? _formatDuration(duration!) : null;

  /// 是否有歌曲在播放
  bool get hasMusic => currentMusic != null;

  /// 是否可以播放/暂停
  bool get canTogglePlay => hasMusic && playbackState != PlaybackState.error;

  static String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// 播放器状态 Notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  Timer? _progressTimer;
  StreamSubscription<Message>? _messageSubscription;
  PlayerAudioBridge? _audioBridge;

  PlayerNotifier() : super(const PlayerState()) {
    _init();
  }

  void _init() {
    _audioBridge = PlayerAudioBridge(
      onPositionChanged: _onAudioPositionChanged,
      onPlaybackChanged: _onAudioPlaybackChanged,
      onError: handleError,
    );

    // 监听 WebSocket 消息
    _messageSubscription = stompService.messageStream.listen(_handleMessage);

    // 启动进度更新定时器
    _startProgressTimer();
  }

  /// 启动进度更新定时器
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateProgress();
    });
  }

  /// 更新播放进度
  void _updateProgress() {
    if (state.currentMusic?.url != null) {
      return;
    }

    if (state.playbackState != PlaybackState.playing ||
        state.startTime == null ||
        state.duration == null) {
      return;
    }

    final elapsed = DateTime.now().difference(state.startTime!).inMilliseconds;
    final newProgress = (elapsed / state.duration!).clamp(0.0, 1.0);

    state = state.copyWith(progress: newProgress);

    // 播放完成
    if (newProgress >= 1.0) {
      state = state.copyWith(playbackState: PlaybackState.idle);
    }
  }

  /// 处理 WebSocket 消息
  void _handleMessage(Message message) {
    switch (message.type) {
      case MessageType.music:
        // 新歌曲开始播放
        final music = message.musicData;
        if (music != null) {
          _onNewMusic(music);
        }
        break;

      case MessageType.volume:
        // 音量变更
        if (message.data != null) {
          final newVolume = message.data is int
              ? message.data as int
              : int.tryParse(message.data.toString()) ?? state.volume;
          state = state.copyWith(volume: newVolume.clamp(0, 100));
        }
        break;

      default:
        break;
    }
  }

  /// 新歌曲播放
  void _onNewMusic(Music music) {
    _ensureAudioBridge();
    final now = DateTime.now();
    final pushTime = music.pushTime != null
        ? DateTime.fromMillisecondsSinceEpoch(music.pushTime!)
        : now;
    final joinSync =
        music.pushTime != null &&
        now.difference(pushTime).inSeconds >= 3 &&
        state.currentMusic == null;
    final muted = joinSync ? true : state.isMuted;

    // 计算当前进度（如果歌曲已经开始播放一段时间）
    double initialProgress = 0.0;
    if (music.duration != null && music.duration! > 0) {
      final elapsed = now.difference(pushTime).inMilliseconds;
      initialProgress = (elapsed / music.duration!).clamp(0.0, 1.0);
    }

    state = PlayerState(
      currentMusic: music,
      playbackState: PlaybackState.playing,
      progress: initialProgress,
      volume: state.volume,
      isMuted: muted,
      startTime: pushTime,
      duration: music.duration,
    );

    final url = music.url;
    if (url != null && url.isNotEmpty) {
      unawaited(
        _audioBridge!.load(
          // _audioBridge is ensured above.
          url,
          autoplay: true,
          volume: (muted ? 0 : state.volume) / 100,
        ),
      );
    } else {
      handleError('当前歌曲没有可播放的音频地址');
    }
  }

  void syncSnapshot(Music music) {
    _onNewMusic(music);
  }

  /// 播放/暂停切换
  void togglePlayPause() {
    if (!state.canTogglePlay) return;
    _ensureAudioBridge();

    if (state.playbackState == PlaybackState.playing) {
      unawaited(_audioBridge!.pause());
      state = state.copyWith(playbackState: PlaybackState.paused, error: null);
    } else {
      unawaited(_audioBridge!.play());
      state = state.copyWith(playbackState: PlaybackState.playing, error: null);
    }
  }

  /// 设置音量
  void setVolume(int volume) {
    final newVolume = volume.clamp(0, 100);
    _ensureAudioBridge();
    _audioBridge!.setVolume(newVolume / 100);
    state = state.copyWith(volume: newVolume, isMuted: newVolume == 0);
  }

  /// 静音切换
  void toggleMute() {
    final muted = !state.isMuted;
    _ensureAudioBridge();
    _audioBridge!.setVolume(muted ? 0 : state.volume / 100);
    state = state.copyWith(isMuted: muted);
  }

  /// 设置播放进度（拖动进度条）
  void seekTo(double progress) {
    if (!state.hasMusic || state.duration == null) return;
    _ensureAudioBridge();

    final newProgress = progress.clamp(0.0, 1.0);
    final newPosition = (newProgress * state.duration!).toInt();

    // 重新计算 startTime，使当前位置等于目标位置
    final newStartTime = DateTime.now().subtract(
      Duration(milliseconds: newPosition),
    );

    unawaited(_audioBridge!.seekTo(Duration(milliseconds: newPosition)));
    state = state.copyWith(progress: newProgress, startTime: newStartTime);
  }

  /// 播放完成
  void onComplete() {
    state = state.copyWith(playbackState: PlaybackState.idle, progress: 0.0);
  }

  /// 播放错误
  void handleError(String error) {
    state = state.copyWith(playbackState: PlaybackState.error, error: error);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  void _ensureAudioBridge() {
    _audioBridge ??= PlayerAudioBridge(
      onPositionChanged: _onAudioPositionChanged,
      onPlaybackChanged: _onAudioPlaybackChanged,
      onError: handleError,
    );
  }

  void _onAudioPositionChanged(Duration position, Duration? duration) {
    final totalDuration = duration?.inMilliseconds ?? state.duration;
    if (totalDuration == null || totalDuration <= 0) {
      return;
    }

    state = state.copyWith(
      progress: (position.inMilliseconds / totalDuration).clamp(0.0, 1.0),
      duration: totalDuration,
      startTime: DateTime.now().subtract(position),
      error: null,
    );
  }

  void _onAudioPlaybackChanged(bool isPlaying) {
    final nextState = isPlaying ? PlaybackState.playing : PlaybackState.paused;
    state = state.copyWith(playbackState: nextState);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _messageSubscription?.cancel();
    _audioBridge?.dispose();
    super.dispose();
  }
}

/// PlayerProvider 全局实例
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier();
});
