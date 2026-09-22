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
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            final destination = options.uri;
            _requireBackendOrigin(destination);
            // Login bodies, bearer headers and signed/query media URLs all
            // contain credentials. Do not send any API request to an unpaired
            // discovery result, including a candidate-login bootstrap.
            _requireTrustedBackend();
            final hasCredentials =
                options.headers.keys.any(
                  (key) => key.toLowerCase() == 'authorization',
                ) ||
                destination.queryParameters.containsKey('token');
            if (hasCredentials &&
                _tokenOrigin != null &&
                _origin(destination) != _tokenOrigin) {
              throw StateError(
                'The server address changed. Sign in to the selected server again.',
              );
            }
            // A redirect must not carry bearer/query credentials to a second
            // authority. API paths are canonical and need no redirect replay.
            options.followRedirects = false;
            handler.next(options);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: error.toString().replaceFirst('Bad state: ', ''),
                error: error,
              ),
            );
          }
        },
      ),
    );
  }

  final BackendResolver? _resolver;
  late final Dio dio;
  String? _token;
  String? _tokenOrigin;

  static String _origin(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';

  void _requireBackendOrigin(Uri uri) {
    final backend = Uri.parse(_baseUrl);
    if (!{'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        _origin(uri) != _origin(backend)) {
      throw StateError('The requested URL is outside the selected backend.');
    }
  }

  void _requireTrustedBackend() {
    if (_resolver != null && !_resolver.allowsCredentials) {
      throw StateError(
        'Select the server address explicitly in Server Connection settings '
        'before signing in. Automatic discovery cannot verify its identity.',
      );
    }
  }

  static bool _isConnectionFailure(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.error is SocketException;

  String get _baseUrl => _resolver?.baseUrl ?? AppConfig.apiBaseUrl;

  void setToken(String? token) {
    _token = token;
    _tokenOrigin = token == null ? null : _origin(Uri.parse(_baseUrl));
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
    if (token != null || params['token'] != null) {
      _requireTrustedBackend();
      if (_tokenOrigin != null && _origin(Uri.parse(base)) != _tokenOrigin) {
        throw StateError('The server address changed. Sign in again.');
      }
    }
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
        DioExceptionType.cancel =>
          err.error is StateError
              ? err.message ?? fallback
              : 'Request cancelled.',
        DioExceptionType.badCertificate =>
          'The server could not establish a secure connection.',
        _ => fallback,
      };
    }
    if (err is Exception) return err.toString().replaceFirst('Exception: ', '');
    return fallback;
  }
}
