typedef PositionChanged = void Function(Duration position, Duration? duration);
typedef PlaybackChanged = void Function(bool isPlaying);
typedef ErrorChanged = void Function(String error);

class PlayerAudioBridge {
  PlayerAudioBridge({
    required PositionChanged onPositionChanged,
    required PlaybackChanged onPlaybackChanged,
    required ErrorChanged onError,
  });

  Future<void> load(String url, {bool autoplay = true, double volume = 0.8}) {
    return Future.value();
  }

  Future<void> play() {
    return Future.value();
  }

  Future<void> pause() {
    return Future.value();
  }

  Future<void> seekTo(Duration position) {
    return Future.value();
  }

  void setVolume(double volume) {}

  void dispose() {}
}
