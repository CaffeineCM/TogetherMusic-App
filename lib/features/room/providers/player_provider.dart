import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/models/music.dart';
import '../../../core/models/playback_snapshot.dart';
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

  // 播放进度锚点
  final int positionMs;
  final DateTime? positionUpdatedAt;
  final int? duration;

  const PlayerState({
    this.currentMusic,
    this.playbackState = PlaybackState.idle,
    this.progress = 0.0,
    this.volume = 80,
    this.isMuted = true,
    this.error,
    this.positionMs = 0,
    this.positionUpdatedAt,
    this.duration,
  });

  PlayerState copyWith({
    Music? currentMusic,
    PlaybackState? playbackState,
    double? progress,
    int? volume,
    bool? isMuted,
    String? error,
    int? positionMs,
    DateTime? positionUpdatedAt,
    int? duration,
  }) {
    return PlayerState(
      currentMusic: currentMusic ?? this.currentMusic,
      playbackState: playbackState ?? this.playbackState,
      progress: progress ?? this.progress,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      error: error,
      positionMs: positionMs ?? this.positionMs,
      positionUpdatedAt: positionUpdatedAt ?? this.positionUpdatedAt,
      duration: duration ?? this.duration,
    );
  }

  /// 当前播放位置（毫秒）
  int get currentPosition {
    final total = duration;
    final anchor = positionUpdatedAt;
    if (total == null || total <= 0) return 0;
    if (playbackState == PlaybackState.playing && anchor != null) {
      final elapsed = DateTime.now().difference(anchor).inMilliseconds;
      return (positionMs + elapsed).clamp(0, total);
    }
    return positionMs.clamp(0, total);
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

    if (state.playbackState != PlaybackState.playing || state.duration == null) {
      return;
    }

    final newProgress = (state.currentPosition / state.duration!).clamp(0.0, 1.0);

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

      case MessageType.playback:
        final playback = message.playbackData;
        if (playback != null) {
          unawaited(_applyPlaybackSnapshot(playback, fromRemote: true));
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
    final snapshot = PlaybackSnapshot(
      music: music,
      status: PlaybackSyncStatus.playing,
      positionMs: 0,
      updatedAt: music.pushTime ?? DateTime.now().millisecondsSinceEpoch,
      serverTime: DateTime.now().millisecondsSinceEpoch,
    );
    unawaited(_applyPlaybackSnapshot(snapshot, fromRemote: true));
  }

  void syncSnapshot(Music music) {
    _onNewMusic(music);
  }

  void syncPlayback(PlaybackSnapshot snapshot) {
    unawaited(_applyPlaybackSnapshot(snapshot, fromRemote: true));
  }

  /// 播放/暂停切换
  void togglePlayPause() {
    if (!state.canTogglePlay) return;

    if (state.playbackState == PlaybackState.playing) {
      final currentPosition = state.currentPosition;
      state = state.copyWith(
        playbackState: PlaybackState.paused,
        positionMs: currentPosition,
        positionUpdatedAt: DateTime.now(),
        progress: state.duration != null && state.duration! > 0
            ? (currentPosition / state.duration!).clamp(0.0, 1.0)
            : state.progress,
        error: null,
      );
      _ensureAudioBridge();
      unawaited(_audioBridge!.pause());
      stompService.pausePlayback();
    } else {
      state = state.copyWith(
        playbackState: PlaybackState.playing,
        positionUpdatedAt: DateTime.now(),
        error: null,
      );
      _ensureAudioBridge();
      unawaited(_audioBridge!.play());
      stompService.resumePlayback();
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

    unawaited(_audioBridge!.seekTo(Duration(milliseconds: newPosition)));
    state = state.copyWith(
      progress: newProgress,
      positionMs: newPosition,
      positionUpdatedAt: DateTime.now(),
    );
    stompService.seekPlayback(newPosition);
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
      positionMs: position.inMilliseconds,
      positionUpdatedAt: DateTime.now(),
      error: null,
    );
  }

  void _onAudioPlaybackChanged(bool isPlaying) {
    final nextState = isPlaying ? PlaybackState.playing : PlaybackState.paused;
    state = state.copyWith(
      playbackState: nextState,
      positionUpdatedAt: DateTime.now(),
    );
  }

  Future<void> _applyPlaybackSnapshot(
    PlaybackSnapshot snapshot, {
    required bool fromRemote,
  }) async {
    _ensureAudioBridge();

    if (snapshot.music == null) {
      await _audioBridge!.pause();
      state = state.copyWith(
        currentMusic: null,
        playbackState: PlaybackState.idle,
        progress: 0.0,
        positionMs: 0,
        positionUpdatedAt: null,
        duration: 0,
        error: null,
      );
      return;
    }

    final music = snapshot.music!;
    final duration = music.duration ?? state.duration ?? 0;
    final effectivePosition = _resolveSnapshotPosition(snapshot, duration);
    final joinSync = fromRemote && state.currentMusic == null;
    final muted = joinSync ? true : state.isMuted;
    final previousMusic = state.currentMusic;
    final previousPlaybackState = state.playbackState;
    final previousPosition = state.currentPosition;
    final isNewTrack =
        previousMusic?.id != music.id ||
        previousMusic?.pushTime != music.pushTime;
    final targetPlaybackState = switch (snapshot.status) {
      PlaybackSyncStatus.playing => PlaybackState.playing,
      PlaybackSyncStatus.paused => PlaybackState.paused,
      PlaybackSyncStatus.idle => PlaybackState.idle,
    };

    state = state.copyWith(
      currentMusic: music,
      playbackState: targetPlaybackState,
      progress: duration > 0 ? (effectivePosition / duration).clamp(0.0, 1.0) : 0.0,
      duration: duration,
      isMuted: muted,
      positionMs: effectivePosition,
      positionUpdatedAt: DateTime.now(),
      error: null,
    );

    final url = music.url;
    if (url == null || url.isEmpty) {
      handleError('当前歌曲没有可播放的音频地址');
      return;
    }

    if (isNewTrack) {
      await _audioBridge!.load(
        url,
        autoplay: false,
        volume: (muted ? 0 : state.volume) / 100,
      );
    } else {
      _audioBridge!.setVolume((muted ? 0 : state.volume) / 100);
    }

    final positionDrift = (previousPosition - effectivePosition).abs();
    final playbackStateChanged = previousPlaybackState != targetPlaybackState;
    final shouldSeek = isNewTrack || positionDrift > 1500;
    final shouldApplyPlaybackCommand =
        isNewTrack ||
        playbackStateChanged ||
        targetPlaybackState == PlaybackState.paused ||
        targetPlaybackState == PlaybackState.idle;

    if (shouldSeek) {
      await _audioBridge!.seekTo(Duration(milliseconds: effectivePosition));
    }

    if (shouldApplyPlaybackCommand) {
      if (snapshot.status == PlaybackSyncStatus.playing) {
        await _audioBridge!.play();
      } else {
        await _audioBridge!.pause();
      }
    }
  }

  int _resolveSnapshotPosition(PlaybackSnapshot snapshot, int duration) {
    var position = snapshot.positionMs;
    if (snapshot.status == PlaybackSyncStatus.playing &&
        snapshot.updatedAt > 0 &&
        snapshot.serverTime > 0) {
      position += snapshot.serverTime - snapshot.updatedAt;
    }
    if (duration <= 0) {
      return position.clamp(0, 1 << 30);
    }
    return position.clamp(0, duration);
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
