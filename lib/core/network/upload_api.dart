import 'api_client.dart';

/// 上传相关 API
class UploadApi {
  /// 获取上传的音频列表
  /// GET /upload/audio/list
  static Future<List<UploadedAudio>> getAudioList() async {
    final response = await apiClient.get(
      '/upload/audio/list',
      fromData: (data) {
        final list = data as List<dynamic>;
        return list
            .map((item) => UploadedAudio.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    return response.isSuccess && response.data != null
        ? response.data as List<UploadedAudio>
        : [];
  }

  /// 上传音频文件
  /// POST /upload/audio
  static Future<UploadedAudio?> uploadAudio(String filePath) async {
    final response = await apiClient.upload(
      '/upload/audio',
      filePath: filePath,
      fieldName: 'file',
      fromData: (data) => UploadedAudio.fromJson(data as Map<String, dynamic>),
    );

    return response.isSuccess ? response.data : null;
  }

  /// 删除上传的音频
  /// DELETE /upload/audio/{fileId}
  static Future<bool> deleteAudio(String fileId) async {
    final response = await apiClient.delete('/upload/audio/$fileId');
    return response.isSuccess;
  }
}

/// 上传的音频文件信息
class UploadedAudio {
  final String id;
  final String name;
  final String? artist;
  final int? duration;
  final String url;
  final DateTime uploadedAt;

  UploadedAudio({
    required this.id,
    required this.name,
    this.artist,
    this.duration,
    required this.url,
    required this.uploadedAt,
  });

  factory UploadedAudio.fromJson(Map<String, dynamic> json) {
    return UploadedAudio(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String?,
      duration: json['duration'] as int?,
      url: json['url'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }
}
