import 'api_client.dart';

String? toProxiedImageUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) {
    return rawUrl;
  }

  final normalized = rawUrl.startsWith('http://')
      ? 'https://${rawUrl.substring(7)}'
      : rawUrl;
  final encoded = Uri.encodeQueryComponent(normalized);
  return '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/music/image?url=$encoded';
}
