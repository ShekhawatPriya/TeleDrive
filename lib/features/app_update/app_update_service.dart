import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import 'app_update_models.dart';

class AppUpdateFetchException implements Exception {
  AppUpdateFetchException(this.message);
  final String message;
  @override
  String toString() => 'AppUpdateFetchException: $message';
}

class AppUpdateService {
  AppUpdateService({Dio? dio, PackageInfo? packageInfoOverride})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              responseType: ResponseType.json,
              headers: {'Accept': 'application/json'},
            ),
          ),
      _packageInfoOverride = packageInfoOverride;

  final Dio _dio;
  final PackageInfo? _packageInfoOverride;
  PackageInfo? _cachedPackageInfo;

  Future<PackageInfo> _loadPackageInfo() async {
    final override = _packageInfoOverride;
    if (override != null) return override;
    return _cachedPackageInfo ??= await PackageInfo.fromPlatform();
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;
    if (!AppConfig.appUpdateChecksEnabled) return null;

    final url = AppConfig.appUpdateManifestUrl;
    if (url.isEmpty) return null;

    final Response<dynamic> response;
    try {
      response = await _dio.getUri<dynamic>(
        Uri.parse(url),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
        ),
      );
    } on DioException catch (e) {
      throw AppUpdateFetchException(_describeDioError(e));
    } catch (e) {
      throw AppUpdateFetchException('Network error');
    }

    final data = _decodeBody(response.data);
    final manifest = AppUpdateManifest.tryParse(data);
    final android = manifest?.android;
    if (android == null) return null;

    final info = await _loadPackageInfo();
    final installedCode = int.tryParse(info.buildNumber.trim()) ?? 0;
    if (android.versionCode <= installedCode) return null;

    return AppUpdateInfo(
      installedVersionName: info.version,
      installedVersionCode: installedCode,
      latestVersionName: android.versionName,
      latestVersionCode: android.versionCode,
      apkUrl: android.apkUrl,
      releaseNotes: android.releaseNotes,
      mandatory: android.mandatory,
      publishedAt: android.publishedAt,
    );
  }

  Object? _decodeBody(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) return raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (raw is List<int>) {
      try {
        return jsonDecode(utf8.decode(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _describeDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        return 'Server returned ${code ?? 'unexpected response'}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Could not reach update server';
      case DioExceptionType.badCertificate:
        return 'Invalid server certificate';
      case DioExceptionType.unknown:
        return 'Network error';
    }
  }
}
