import 'music.dart';

enum PlaybackSyncStatus { idle, playing, paused }

class PlaybackSnapshot {
  final Music? music;
  final PlaybackSyncStatus status;
  final int positionMs;
  final int updatedAt;
  final int serverTime;

  const PlaybackSnapshot({
    required this.music,
    required this.status,
    required this.positionMs,
    required this.updatedAt,
    required this.serverTime,
  });

  factory PlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    return PlaybackSnapshot(
      music: json['music'] == null
          ? null
          : Music.fromJson(json['music'] as Map<String, dynamic>),
      status: _parseStatus(json['status'] as String?),
      positionMs: json['positionMs'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      serverTime: json['serverTime'] as int? ?? 0,
    );
  }

  static PlaybackSyncStatus _parseStatus(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'playing':
        return PlaybackSyncStatus.playing;
      case 'paused':
        return PlaybackSyncStatus.paused;
      default:
        return PlaybackSyncStatus.idle;
    }
  }
}
