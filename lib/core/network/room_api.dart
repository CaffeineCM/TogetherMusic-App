import '../models/room.dart';
import '../models/music.dart';
import '../models/playback_snapshot.dart';
import 'api_client.dart';

/// 房间相关 API
class RoomApi {
  /// 获取房间列表
  /// GET /rooms
  static Future<List<RoomSummary>?> getRoomList() async {
    try {
      final response = await apiClient.get(
        '/rooms',
        fromData: (data) {
          final list = data as List<dynamic>;
          return list
              .map((item) => RoomSummary.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      return response.isSuccess && response.data != null
          ? response.data as List<RoomSummary>
          : [];
    } catch (e) {
      return null;
    }
  }

  static Future<Music?> getCurrentPlaying(String houseId) async {
    try {
      final response = await apiClient.get(
        '/rooms/$houseId/playing',
        fromData: (data) =>
            data == null ? null : Music.fromJson(data as Map<String, dynamic>),
      );

      return response.isSuccess ? response.data : null;
    } catch (e) {
      return null;
    }
  }

  static Future<PlaybackSnapshot?> getPlaybackSnapshot(String houseId) async {
    try {
      final response = await apiClient.get(
        '/rooms/$houseId/playback',
        fromData: (data) => PlaybackSnapshot.fromJson(data as Map<String, dynamic>),
      );

      return response.isSuccess ? response.data as PlaybackSnapshot? : null;
    } catch (e) {
      return null;
    }
  }

  /// 开发环境：清理所有房间和 IP 限制数据
  static Future<String?> clearDevRoomData() async {
    try {
      final response = await apiClient.post('/dev/rooms/clear');
      return response.isSuccess ? response.message ?? '清理成功' : response.message;
    } catch (e) {
      return '清理失败: $e';
    }
  }
}
