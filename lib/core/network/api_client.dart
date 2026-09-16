import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'backend_resolver.dart';

class ApiClient {
  /// Without a [BackendResolver] (unit tests), the client keeps the legacy
  /// behavior: a fixed base URL from [AppConfig.apiBaseUrl].
  ApiClient([this._resolver]) {
    dio = Dio(
      BaseOptions(
        baseUrl: _resolver?.baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
      ),
    );
    final resolver = _resolver;
    if (resolver != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            await resolver.ensureResolved();
            // Give a just-started backend a chance before giving up, then
            // fail fast with a clear message rather than letting the request
            // hang for the full connect timeout against a dead address.
            await resolver.recheckIfUnreachable();
            if (resolver.status == BackendStatus.unreachable) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  message: resolver.unreachableMessage,
                ),
              );
              return;
            }
            options.baseUrl = resolver.baseUrl;
            handler.next(options);
          },
          onError: (err, handler) async {
            if (!_isConnectionFailure(err) ||
                err.requestOptions.extra['backendRetried'] == true) {
              handler.next(err);
              return;
            }
            final moved = await resolver.onConnectionFailure(
              err.requestOptions.baseUrl,
            );
            // Only GETs are safe to replay blindly; mutating requests just
            // fail once and succeed on the caller's next attempt.
            if (moved && err.requestOptions.method.toUpperCase() == 'GET') {
              try {
                final retryOptions = err.requestOptions
                  ..extra['backendRetried'] = true
                  ..baseUrl = resolver.baseUrl;
                handler.resolve(await dio.fetch<dynamic>(retryOptions));
                return;
              } catch (_) {
                // Fall through and surface the original error.
              }
            }
            handler.next(err);
          },
        ),
      );
    }
  }

  final BackendResolver? _resolver;
  late final Dio dio;
  String? _token;

  static bool _isConnectionFailure(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.error is SocketException;

  String get _baseUrl => _resolver?.baseUrl ?? AppConfig.apiBaseUrl;

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
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return path;
    final base = _baseUrl;
    final basePath = Uri.parse(base).path;
    final normalizedPath = basePath.isNotEmpty && path.startsWith('$basePath/')
        ? path.substring(basePath.length)
        : path;
    final token = _token;
    if (token == null) {
      return AppConfig.buildApiUri(base, normalizedPath, params).toString();
    }
    return AppConfig.buildApiUri(base, normalizedPath, {
      'token': token,
      ...params,
    }).toString();
  }

  String errorMessage(Object err, [String fallback = 'Request failed.']) {
    if (err is DioException) {
      final data = err.response?.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      return switch (err.type) {
        DioExceptionType.connectionError =>
          _resolver?.unreachableMessage ??
              'TeleDrive is temporarily unavailable. Please try again.',
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Please try again.',
        DioExceptionType.cancel => 'Request cancelled.',
        DioExceptionType.badCertificate =>
          'The server could not establish a secure connection.',
        _ => fallback,
      };
    }
    if (err is Exception) return err.toString().replaceFirst('Exception: ', '');
    return fallback;
  }
}
