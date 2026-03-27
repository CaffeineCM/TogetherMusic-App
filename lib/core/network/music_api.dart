import '../models/music.dart';
import '../models/music_discovery.dart';
import 'api_client.dart';

/// 音乐相关 API
class MusicApi {
  /// 搜索歌曲
  /// GET /music/search?keyword=&source=
  static Future<List<Music>> search({
    required String houseId,
    required String keyword,
    String source = 'wy',
  }) async {
    final response = await apiClient.get(
      '/music/search',
      queryParameters: {
        'houseId': houseId,
        'keyword': keyword,
        'source': source,
      },
      fromData: (data) {
        if (data is List<dynamic>) {
          return data
              .map((item) => Music.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        if (data is Map<String, dynamic>) {
          return [Music.fromJson(data)];
        }
        return <Music>[];
      },
    );

    return response.isSuccess && response.data != null
        ? response.data as List<Music>
        : [];
  }

  static Future<MusicDiscoveryContext> getDiscoveryContext({
    required String houseId,
  }) async {
    final response = await apiClient.get(
      '/music/discovery/context',
      queryParameters: {'houseId': houseId},
      fromData: (data) =>
          MusicDiscoveryContext.fromJson(data as Map<String, dynamic>),
    );

    return response.isSuccess && response.data != null
        ? response.data as MusicDiscoveryContext
        : const MusicDiscoveryContext(
            canViewHostPlaylists: false,
            playlistSource: 'wy',
          );
  }

  static Future<List<MusicPlaylistSummary>> getRecommendedPlaylists({
    required String houseId,
  }) async {
    final response = await apiClient.get(
      '/music/playlists/recommended',
      queryParameters: {'houseId': houseId},
      fromData: (data) => (data as List<dynamic>)
          .map(
            (item) =>
                MusicPlaylistSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );

    return response.isSuccess && response.data != null
        ? response.data as List<MusicPlaylistSummary>
        : [];
  }

  static Future<List<MusicPlaylistSummary>> getHostPlaylists({
    required String houseId,
  }) async {
    final response = await apiClient.get(
      '/music/playlists/host-favorites',
      queryParameters: {'houseId': houseId},
      fromData: (data) => (data as List<dynamic>)
          .map(
            (item) =>
                MusicPlaylistSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );

    return response.isSuccess && response.data != null
        ? response.data as List<MusicPlaylistSummary>
        : [];
  }

  static Future<List<Music>> getPlaylistDetail({
    required String houseId,
    required String playlistId,
  }) async {
    final response = await apiClient.get(
      '/music/playlists/$playlistId',
      queryParameters: {'houseId': houseId},
      fromData: (data) => (data as List<dynamic>)
          .map((item) => Music.fromJson(item as Map<String, dynamic>))
          .toList(),
    );

    return response.isSuccess && response.data != null
        ? response.data as List<Music>
        : [];
  }

  static Future<List<MusicToplistSummary>> getToplists({
    required String houseId,
  }) async {
    final response = await apiClient.get(
      '/music/toplists',
      queryParameters: {'houseId': houseId},
      fromData: (data) => (data as List<dynamic>)
          .map(
            (item) =>
                MusicToplistSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );

    return response.isSuccess && response.data != null
        ? response.data as List<MusicToplistSummary>
        : [];
  }
}
