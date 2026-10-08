import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import 'github_release_models.dart';

class ChangelogFetchException implements Exception {
  ChangelogFetchException(this.message);
  final String message;
  @override
  String toString() => 'ChangelogFetchException: $message';
}

/// Fetches the published GitHub Releases for the configured repository.
///
/// Uses its own [Dio] (not the authenticated app [ApiClient]) because it talks
/// to api.github.com, not the TeleDrive backend.
class ChangelogService {
  ChangelogService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;

  Future<List<GithubRelease>> fetchReleases({int perPage = 100}) async {
    final url = AppConfig.githubReleasesApiUrl;
    if (url.isEmpty) return const [];

    final releases = <GithubRelease>[];
    for (var page = 1; ; page++) {
      final Response<dynamic> response;
      try {
        response = await _dio.getUri<dynamic>(
          Uri.parse(url).replace(
            queryParameters: {
              'per_page': '${perPage.clamp(1, 100)}',
              'page': '$page',
            },
          ),
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          ),
        );
      } on DioException catch (e) {
        throw ChangelogFetchException(_describeDioError(e));
      } catch (_) {
        throw ChangelogFetchException('Network error');
      }

      final decoded = _decodeBody(response.data);
      if (decoded is! List) {
        throw ChangelogFetchException('GitHub returned invalid release data');
      }
      releases.addAll(GithubRelease.parseList(decoded));
      if (decoded.length < perPage.clamp(1, 100)) return releases;
    }
  }

  Object? _decodeBody(Object? raw) {
    if (raw == null) return null;
    if (raw is List || raw is Map) return raw;
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
        if (code == 403 || code == 429) {
          return 'GitHub rate limit reached. Try again later.';
        }
        if (code == 404) {
          return 'Repository or releases not found';
        }
        return 'GitHub returned ${code ?? 'an unexpected response'}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Could not reach GitHub';
      case DioExceptionType.badCertificate:
        return 'Invalid server certificate';
      case DioExceptionType.unknown:
        return 'Network error';
    }
  }
}
