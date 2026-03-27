class MusicDiscoveryContext {
  final bool canViewHostPlaylists;
  final String playlistSource;

  const MusicDiscoveryContext({
    required this.canViewHostPlaylists,
    required this.playlistSource,
  });

  factory MusicDiscoveryContext.fromJson(Map<String, dynamic> json) {
    return MusicDiscoveryContext(
      canViewHostPlaylists: json['canViewHostPlaylists'] as bool? ?? false,
      playlistSource: json['playlistSource'] as String? ?? 'wy',
    );
  }
}

class MusicPlaylistSummary {
  final String id;
  final String name;
  final String? coverUrl;
  final String? creatorName;
  final int? trackCount;
  final int? playCount;
  final String? description;
  final String source;

  const MusicPlaylistSummary({
    required this.id,
    required this.name,
    this.coverUrl,
    this.creatorName,
    this.trackCount,
    this.playCount,
    this.description,
    this.source = 'wy',
  });

  factory MusicPlaylistSummary.fromJson(Map<String, dynamic> json) {
    return MusicPlaylistSummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '未命名歌单',
      coverUrl: json['coverUrl'] as String?,
      creatorName: json['creatorName'] as String?,
      trackCount: json['trackCount'] as int?,
      playCount: json['playCount'] as int?,
      description: json['description'] as String?,
      source: json['source'] as String? ?? 'wy',
    );
  }
}

class MusicToplistSummary {
  final String id;
  final String name;
  final String? coverUrl;
  final String? description;
  final String? updateFrequency;
  final String source;

  const MusicToplistSummary({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.updateFrequency,
    this.source = 'wy',
  });

  factory MusicToplistSummary.fromJson(Map<String, dynamic> json) {
    return MusicToplistSummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '未命名榜单',
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      updateFrequency: json['updateFrequency'] as String?,
      source: json['source'] as String? ?? 'wy',
    );
  }
}
