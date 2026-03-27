// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

typedef PositionChanged = void Function(Duration position, Duration? duration);
typedef PlaybackChanged = void Function(bool isPlaying);
typedef ErrorChanged = void Function(String error);

class PlayerAudioBridge {
  final PositionChanged _onPositionChanged;
  final PlaybackChanged _onPlaybackChanged;
  final ErrorChanged _onError;

  late final html.AudioElement _audio;
  StreamSubscription<html.Event>? _timeUpdateSub;
  StreamSubscription<html.Event>? _loadedMetaSub;
  StreamSubscription<html.Event>? _playSub;
  StreamSubscription<html.Event>? _pauseSub;
  StreamSubscription<html.Event>? _endedSub;
  StreamSubscription<html.Event>? _errorSub;

  PlayerAudioBridge({
    required PositionChanged onPositionChanged,
    required PlaybackChanged onPlaybackChanged,
    required ErrorChanged onError,
  }) : _onPositionChanged = onPositionChanged,
       _onPlaybackChanged = onPlaybackChanged,
       _onError = onError {
    _audio = html.AudioElement()
      ..preload = 'auto'
      ..crossOrigin = 'anonymous';

    _timeUpdateSub = _audio.onTimeUpdate.listen((_) => _emitPosition());
    _loadedMetaSub = _audio.onLoadedMetadata.listen((_) => _emitPosition());
    _playSub = _audio.onPlay.listen((_) => _onPlaybackChanged(true));
    _pauseSub = _audio.onPause.listen((_) => _onPlaybackChanged(false));
    _endedSub = _audio.onEnded.listen((_) => _onPlaybackChanged(false));
    _errorSub = _audio.onError.listen((_) {
      final mediaError = _audio.error;
      _onError(mediaError?.message ?? '音频播放失败，可能是链接失效或浏览器拦截');
    });
  }

  Future<void> load(
    String url, {
    bool autoplay = true,
    double volume = 0.8,
  }) async {
    _audio
      ..src = url
      ..volume = volume.clamp(0.0, 1.0)
      ..load();

    if (autoplay) {
      try {
        await _audio.play();
      } catch (_) {
        _onError('浏览器阻止了自动播放，请点击播放按钮继续');
      }
    }
  }

  Future<void> play() async {
    try {
      await _audio.play();
    } catch (_) {
      _onError('播放失败，请检查浏览器是否阻止音频播放');
    }
  }

  Future<void> pause() async {
    _audio.pause();
  }

  Future<void> seekTo(Duration position) async {
    _audio.currentTime = position.inMilliseconds / 1000;
    _emitPosition();
  }

  void setVolume(double volume) {
    _audio.volume = volume.clamp(0.0, 1.0);
  }

  void _emitPosition() {
    final durationSeconds = _audio.duration;
    final duration = durationSeconds.isFinite
        ? Duration(milliseconds: (durationSeconds * 1000).round())
        : null;
    final position = Duration(
      milliseconds: (_audio.currentTime * 1000).round(),
    );
    _onPositionChanged(position, duration);
  }

  void dispose() {
    _timeUpdateSub?.cancel();
    _loadedMetaSub?.cancel();
    _playSub?.cancel();
    _pauseSub?.cancel();
    _endedSub?.cancel();
    _errorSub?.cancel();
    _audio.pause();
    _audio.src = '';
  }
}
