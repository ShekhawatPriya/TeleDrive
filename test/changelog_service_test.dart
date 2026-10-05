import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/project/changelog_service.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'GITHUB_TOKEN=fixture-unused-token'));
  test(
    'public release history follows pages without sending credentials',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final pages = <int>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(
              request.uri.path,
              '/repos/ShekhawatPriya/TeleDrive/releases',
            );
            final page = int.parse(request.uri.queryParameters['page']!);
            pages.add(page);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: page == 1
                    ? [
                        {
                          'tag_name': 'v3',
                          'body':
                              '**Full Changelog**: https://github.com/example/compare/v2...v3',
                        },
                        {'tag_name': 'v2', 'draft': true},
                      ]
                    : [
                        {'tag_name': 'v1', 'body': 'Original release'},
                      ],
              ),
            );
          },
        ),
      );
      final releases = await ChangelogService(
        dio: dio,
      ).fetchReleases(perPage: 2);
      expect(pages, [1, 2]);
      expect(releases.map((release) => release.tagName), ['v3', 'v1']);
      expect(releases.first.body, contains('/compare/'));
    },
  );
  test(
    'invalid public response is an error rather than an empty history',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: 'invalid json',
            ),
          ),
        ),
      );
      expect(
        ChangelogService(dio: dio).fetchReleases(),
        throwsA(isA<ChangelogFetchException>()),
      );
    },
  );
}
