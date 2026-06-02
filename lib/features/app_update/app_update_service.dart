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
  AppUpdateService({Dio? dio, this._packageInfoOverride})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              responseType: ResponseType.json,
              headers: {'Accept': 'application/json'},
            ),
          );

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

    final token = AppConfig.githubToken;
    // Private repos hide release assets behind the authenticated API; public
    // repos can fetch the raw manifest URL directly. The token presence is the
    // switch, so flipping the repo public (and clearing the token) reverts to
    // the simple path with no code change.
    final resolved = token.isNotEmpty
        ? await _loadViaApi(token)
        : await _loadDirect();
    if (resolved == null) return null;

    final android = resolved.android;
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
      apkAssetApiUrl: resolved.apkAssetApiUrl,
    );
  }

  /// Public-repo path: fetch the raw `latest.json` from its download URL.
  Future<({AndroidUpdateManifest android, String? apkAssetApiUrl})?>
  _loadDirect() async {
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

    final manifest = AppUpdateManifest.tryParse(_decodeBody(response.data));
    final android = manifest?.android;
    if (android == null) return null;
    return (android: android, apkAssetApiUrl: null);
  }

  /// Private-repo path: read the latest Release through the authenticated API,
  /// then pull `latest.json` from its release asset. Also captures the APK
  /// asset's API URL so the download can be resolved to a signed URL later.
  Future<({AndroidUpdateManifest android, String? apkAssetApiUrl})?>
  _loadViaApi(String token) async {
    final Response<dynamic> releaseResponse;
    try {
      releaseResponse = await _dio.getUri<dynamic>(
        Uri.parse(AppConfig.githubLatestReleaseApiUrl),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          headers: _apiHeaders(token, accept: 'application/vnd.github+json'),
        ),
      );
    } on DioException catch (e) {
      throw AppUpdateFetchException(_describeDioError(e));
    } catch (_) {
      throw AppUpdateFetchException('Network error');
    }

    final release = _decodeBody(releaseResponse.data);
    if (release is! Map) return null;
    final assets = release['assets'];
    if (assets is! List) return null;

    String? manifestAssetUrl;
    String? apkAssetUrl;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = '${asset['name'] ?? ''}'.toLowerCase();
      final url = asset['url'];
      if (url is! String || url.isEmpty) continue;
      if (name == 'latest.json') {
        manifestAssetUrl = url;
      } else if (name.endsWith('.apk')) {
        apkAssetUrl = url;
      }
    }
    if (manifestAssetUrl == null) return null;

    final manifestContent = await _fetchAssetBytes(manifestAssetUrl, token);
    final manifest = AppUpdateManifest.tryParse(_decodeBody(manifestContent));
    final android = manifest?.android;
    if (android == null) return null;
    return (android: android, apkAssetApiUrl: apkAssetUrl);
  }

  /// Resolves the actual, launchable download URL for the APK. For a private
  /// repo this is a short-lived signed URL, so it must be resolved at the
  /// moment the user taps download. For a public repo the stored [apkUrl] is
  /// already launchable and returned as-is.
  Future<String?> resolveApkDownloadUrl(AppUpdateInfo info) async {
    final assetUrl = info.apkAssetApiUrl;
    final token = AppConfig.githubToken;
    if (assetUrl == null || token.isEmpty) {
      return info.apkUrl.isEmpty ? null : info.apkUrl;
    }
    try {
      return await _resolveSignedAssetUrl(assetUrl, token);
    } on DioException catch (e) {
      throw AppUpdateFetchException(_describeDioError(e));
    }
  }

  /// Downloads a release asset's content via the API. The asset endpoint
  /// 302-redirects to a signed host that rejects the bearer token, so the
  /// redirect is followed manually with the auth header dropped.
  Future<String?> _fetchAssetBytes(String assetApiUrl, String token) async {
    final signed = await _resolveSignedAssetUrl(assetApiUrl, token);
    if (signed == null) return null;
    final Response<dynamic> contentResponse;
    try {
      contentResponse = await _dio.getUri<dynamic>(
        Uri.parse(signed),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
        ),
      );
    } on DioException catch (e) {
      throw AppUpdateFetchException(_describeDioError(e));
    }
    final data = contentResponse.data;
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    return null;
  }

  /// Performs the authenticated asset request without following the redirect,
  /// returning the `Location` header (the signed, auth-free download URL).
  Future<String?> _resolveSignedAssetUrl(
    String assetApiUrl,
    String token,
  ) async {
    final response = await _dio.getUri<dynamic>(
      Uri.parse(assetApiUrl),
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        // Accept 2xx and 3xx; the redirect status is what we want here.
        validateStatus: (status) => status != null && status < 400,
        headers: _apiHeaders(token, accept: 'application/octet-stream'),
      ),
    );
    final status = response.statusCode ?? 0;
    if (status >= 300 && status < 400) {
      return response.headers.value('location');
    }
    // No redirect (unexpected for assets) — nothing launchable to return.
    return null;
  }

  Map<String, String> _apiHeaders(String token, {required String accept}) {
    return {
      'Accept': accept,
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
    };
  }

  Object? _decodeBody(Object? raw) {
    if (raw == null) return null;
    if (raw is Map || raw is List) return raw;
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
        if (code == 401 || code == 403) {
          return 'Update access denied. Check the GitHub token.';
        }
        if (code == 404) {
          return 'No release found';
        }
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
