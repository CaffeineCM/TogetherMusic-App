import 'api_client.dart';

class MusicAccountApi {
  static final _apiClient = ApiClient();

  static Future<NeteaseAccountStatus?> importNeteaseCookie(
    String cookie, {
    String? uid,
  }) async {
    final response = await _apiClient.post(
      '/user/music-accounts/netease/cookie/import',
      data: {
        'cookie': cookie,
        if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      },
      fromData: (data) =>
          NeteaseAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'Cookie 导入失败');
    }
    return response.data;
  }

  static Future<NeteaseQrStartResult?> startNeteaseQrLogin() async {
    final response = await _apiClient.post(
      '/user/music-accounts/netease/qr/start',
      fromData: (data) =>
          NeteaseQrStartResult.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<NeteaseQrCheckResult?> checkNeteaseQrLogin(String key) async {
    final response = await _apiClient.get(
      '/user/music-accounts/netease/qr/check',
      queryParameters: {'key': key},
      fromData: (data) =>
          NeteaseQrCheckResult.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<NeteaseAccountStatus?> getNeteaseStatus() async {
    final response = await _apiClient.get(
      '/user/music-accounts/netease/status',
      fromData: (data) =>
          NeteaseAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<NeteaseAccountStatus?> refreshNeteaseStatus() async {
    final response = await _apiClient.post(
      '/user/music-accounts/netease/refresh',
      fromData: (data) =>
          NeteaseAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<NeteaseCaptchaSendResult> sendNeteaseCaptcha({
    required String phone,
    String ctcode = '86',
  }) async {
    final response = await _apiClient.post(
      '/user/music-accounts/netease/captcha/send',
      data: {'phone': phone, 'ctcode': ctcode},
    );
    return NeteaseCaptchaSendResult(
      success: response.isSuccess && response.data == true,
      message: response.message,
    );
  }

  static Future<NeteaseAccountStatus?> loginNeteaseByCaptcha({
    required String phone,
    required String captcha,
    String ctcode = '86',
  }) async {
    final response = await _apiClient.post(
      '/user/music-accounts/netease/captcha/login',
      data: {'phone': phone, 'captcha': captcha, 'ctcode': ctcode},
      fromData: (data) =>
          NeteaseAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? '网易云授权失败');
    }
    return response.data;
  }

  static Future<KugouAccountStatus?> importKugouToken(String token) async {
    final response = await _apiClient.post(
      '/user/music-accounts/kugou/token/import',
      data: {'token': token},
      fromData: (data) =>
          KugouAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? '酷狗授权失败');
    }
    return response.data;
  }

  static Future<KugouAccountStatus?> getKugouStatus() async {
    final response = await _apiClient.get(
      '/user/music-accounts/kugou/status',
      fromData: (data) =>
          KugouAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<KugouAccountStatus?> refreshKugouStatus() async {
    final response = await _apiClient.post(
      '/user/music-accounts/kugou/refresh',
      fromData: (data) =>
          KugouAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<KugouQrStartResult?> startKugouQrLogin() async {
    final response = await _apiClient.post(
      '/user/music-accounts/kugou/qr/start',
      fromData: (data) =>
          KugouQrStartResult.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<KugouQrCheckResult?> checkKugouQrLogin(String key) async {
    final response = await _apiClient.get(
      '/user/music-accounts/kugou/qr/check',
      queryParameters: {'key': key},
      fromData: (data) =>
          KugouQrCheckResult.fromJson(data as Map<String, dynamic>),
    );
    return response.isSuccess ? response.data : null;
  }

  static Future<KugouCaptchaSendResult> sendKugouCaptcha({
    required String phone,
  }) async {
    final response = await _apiClient.post(
      '/user/music-accounts/kugou/captcha/send',
      data: {'phone': phone},
      fromData: (data) =>
          KugouCaptchaSendResult.fromJson(data as Map<String, dynamic>),
    );
    if (!response.isSuccess || response.data == null) {
      return KugouCaptchaSendResult(
        success: false,
        message: response.message ?? '验证码发送失败',
      );
    }
    return response.data!;
  }

  static Future<KugouAccountStatus?> loginKugouByCaptcha({
    required String phone,
    required String captcha,
  }) async {
    final response = await _apiClient.post(
      '/user/music-accounts/kugou/captcha/login',
      data: {'phone': phone, 'captcha': captcha},
      fromData: (data) =>
          KugouAccountStatus.fromJson(data as Map<String, dynamic>),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? '酷狗授权失败');
    }
    return response.data;
  }
}

class NeteaseCaptchaSendResult {
  final bool success;
  final String? message;

  const NeteaseCaptchaSendResult({
    required this.success,
    required this.message,
  });
}

class NeteaseQrStartResult {
  final String key;
  final String? qrUrl;
  final String? qrImage;

  const NeteaseQrStartResult({
    required this.key,
    required this.qrUrl,
    required this.qrImage,
  });

  factory NeteaseQrStartResult.fromJson(Map<String, dynamic> json) {
    return NeteaseQrStartResult(
      key: json['key'] as String? ?? '',
      qrUrl: json['qrUrl'] as String?,
      qrImage: json['qrImage'] as String?,
    );
  }
}

class NeteaseQrCheckResult {
  final int code;
  final String? message;
  final bool authorized;
  final String? nickname;

  const NeteaseQrCheckResult({
    required this.code,
    required this.message,
    required this.authorized,
    required this.nickname,
  });

  factory NeteaseQrCheckResult.fromJson(Map<String, dynamic> json) {
    return NeteaseQrCheckResult(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String?,
      authorized: json['authorized'] as bool? ?? false,
      nickname: json['nickname'] as String?,
    );
  }
}

class NeteaseAccountStatus {
  final bool valid;
  final bool refreshed;
  final String? nickname;
  final String? message;

  const NeteaseAccountStatus({
    required this.valid,
    required this.refreshed,
    required this.nickname,
    required this.message,
  });

  factory NeteaseAccountStatus.fromJson(Map<String, dynamic> json) {
    return NeteaseAccountStatus(
      valid: json['valid'] as bool? ?? false,
      refreshed: json['refreshed'] as bool? ?? false,
      nickname: json['nickname'] as String?,
      message: json['message'] as String?,
    );
  }
}

class KugouAccountStatus {
  final bool valid;
  final String? nickname;
  final String? message;

  const KugouAccountStatus({
    required this.valid,
    required this.nickname,
    required this.message,
  });

  factory KugouAccountStatus.fromJson(Map<String, dynamic> json) {
    return KugouAccountStatus(
      valid: json['valid'] as bool? ?? false,
      nickname: json['nickname'] as String?,
      message: json['message'] as String?,
    );
  }
}

class KugouCaptchaSendResult {
  final bool success;
  final String? message;

  const KugouCaptchaSendResult({required this.success, required this.message});

  factory KugouCaptchaSendResult.fromJson(Map<String, dynamic> json) {
    return KugouCaptchaSendResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

class KugouQrStartResult {
  final String key;
  final String? qrUrl;
  final String? qrImage;

  const KugouQrStartResult({
    required this.key,
    required this.qrUrl,
    required this.qrImage,
  });

  factory KugouQrStartResult.fromJson(Map<String, dynamic> json) {
    return KugouQrStartResult(
      key: json['key'] as String? ?? '',
      qrUrl: json['qrUrl'] as String?,
      qrImage: json['qrImage'] as String?,
    );
  }
}

class KugouQrCheckResult {
  final int code;
  final String? message;
  final bool authorized;
  final String? nickname;

  const KugouQrCheckResult({
    required this.code,
    required this.message,
    required this.authorized,
    required this.nickname,
  });

  factory KugouQrCheckResult.fromJson(Map<String, dynamic> json) {
    return KugouQrCheckResult(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String?,
      authorized: json['authorized'] as bool? ?? false,
      nickname: json['nickname'] as String?,
    );
  }
}
