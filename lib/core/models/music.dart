/// 音乐数据模型，对应后端 Music
import '../network/image_url.dart';

/// 音乐数据模型，对应后端 Music
class Music {
  final String id;
  final String name;
  final String? artist;
  final int? duration; // 毫秒
  final String? url;
  final String? lyric;
  final String? pictureUrl;
  final String source;
  final String? quality;
  final int? pickTime;
  final int? pushTime;
  final String? pickedBy;
  final List<String> likedUserIds;

  const Music({
    required this.id,
    required this.name,
    this.artist,
    this.duration,
    this.url,
    this.lyric,
    this.pictureUrl,
    this.source = 'wy',
    this.quality,
    this.pickTime,
    this.pushTime,
    this.pickedBy,
    this.likedUserIds = const [],
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未知歌曲',
      artist: json['artist'] as String?,
      duration: json['duration'] as int?,
      url: json['url'] as String?,
      lyric: json['lyric'] as String?,
      pictureUrl: toProxiedImageUrl(json['pictureUrl'] as String?),
      source: json['source'] as String? ?? 'wy',
      quality: json['quality'] as String?,
      pickTime: json['pickTime'] as int?,
      pushTime: json['pushTime'] as int?,
      pickedBy: json['pickedBy'] as String?,
      likedUserIds:
          (json['likedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// 已播放的毫秒数（基于 pushTime 计算）
  int get elapsedMs {
    if (pushTime == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - pushTime!;
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final total = duration! ~/ 1000;
    final min = total ~/ 60;
    final sec = total % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
