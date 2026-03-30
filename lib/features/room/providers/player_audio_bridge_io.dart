import 'dart:async';

import 'package:just_audio/just_audio.dart';

typedef PositionChanged = void Function(Duration position, Duration? duration);
typedef PlaybackChanged = void Function(bool isPlaying);
typedef ErrorChanged = void Function(String error);

class PlayerAudioBridge {
  final PositionChanged _onPositionChanged;
  final PlaybackChanged _onPlaybackChanged;
  final ErrorChanged _onError;
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;

  Duration? _duration;

  PlayerAudioBridge({
    required PositionChanged onPositionChanged,
    required PlaybackChanged onPlaybackChanged,
    required ErrorChanged onError,
  }) : _onPositionChanged = onPositionChanged,
       _onPlaybackChanged = onPlaybackChanged,
       _onError = onError {
    _positionSub = _player.positionStream.listen(_emitPosition);
    _durationSub = _player.durationStream.listen((duration) {
      _duration = duration;
      _emitPosition(_player.position);
    });
    _playerStateSub = _player.playerStateStream.listen((state) {
      _onPlaybackChanged(state.playing);
      if (state.processingState == ProcessingState.completed) {
        _emitPosition(_duration ?? _player.position);
      }
    });
    _playbackEventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _onError(error.toString());
      },
    );
  }

  Future<void> load(
    String url, {
    bool autoplay = true,
    double volume = 0.8,
  }) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.setUrl(url);
      _emitPosition(_player.position);
      if (autoplay) {
        await _player.play();
      }
    } on PlayerException catch (error) {
      _onError(error.message ?? '音频加载失败');
    } on PlayerInterruptedException catch (error) {
      _onError(error.message ?? '音频加载被中断');
    } catch (error) {
      _onError(error.toString());
    }
  }

  Future<void> play() async {
    try {
      await _player.play();
    } on PlayerException catch (error) {
      _onError(error.message ?? '播放失败');
    } catch (error) {
      _onError(error.toString());
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (error) {
      _onError(error.toString());
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
      _emitPosition(position);
    } catch (error) {
      _onError(error.toString());
    }
  }

  void setVolume(double volume) {
    _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void _emitPosition(Duration position) {
    _onPositionChanged(position, _duration ?? _player.duration);
  }

  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_playerStateSub?.cancel());
    unawaited(_playbackEventSub?.cancel());
    unawaited(_player.dispose());
  }
}
