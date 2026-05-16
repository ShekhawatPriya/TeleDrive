import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
      ),
    );
  }

  late final Dio dio;
  String? _token;

  void setToken(String? token) {
    _token = token;
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  String? get token => _token;

  String mediaUrl(String path, {Map<String, dynamic> params = const {}}) {
    final token = _token;
    if (token == null) return AppConfig.apiUri(path, params).toString();
    return AppConfig.apiUri(path, {'token': token, ...params}).toString();
  }

  String errorMessage(Object err, [String fallback = 'Request failed.']) {
    if (err is DioException) {
      final data = err.response?.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      if (err.message != null) return err.message!;
    }
    if (err is Exception) return err.toString().replaceFirst('Exception: ', '');
    return fallback;
  }
}
