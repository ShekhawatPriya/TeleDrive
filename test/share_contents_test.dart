import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';
import 'package:flutter_m_fsdk/features/share/components/share_contents.dart';
import 'package:flutter_m_fsdk/features/share/components/share_list_tile.dart';

Share fixture() => Share.fromJson({
  'id': 1,
  'token': 'fixture',
  'url': 'https://example.test/s/fixture',
  'primaryName': 'SM',
  'primaryKind': 'folder',
  'permission': 'download',
  'itemCount': 1,
  'items': [
    {'publicId': 'root', 'kind': 'folder', 'name': 'SM', 'relativePath': 'SM'},
    {
      'publicId': 'child',
      'kind': 'folder',
      'name': 'Photos',
      'relativePath': 'SM/Photos',
      'parentPublicId': 'root',
    },
    {
      'publicId': 'file',
      'kind': 'file',
      'name': 'Holiday.jpg',
      'relativePath': 'SM/Photos/Holiday.jpg',
      'parentPublicId': 'child',
      'sizeBytes': 2048,
      'mimeType': 'image/jpeg',
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  test('file and folder kinds come from the API, not name extensions', () {
    final folder = Share.fromListJson({
      'primaryName': 'SM.v2',
      'primaryKind': 'folder',
    });
    final file = Share.fromListJson({
      'primaryName': 'LICENSE',
      'primaryKind': 'file',
    });
    expect(folder.isFolder, isTrue);
    expect(file.isFolder, isFalse);
    expect(fixture().items.last.sizeBytes, 2048);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('folder browser $platform dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                fontFamily: 'Inter',
                platform: platform,
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  highContrast: scale == 2,
                  disableAnimations: true,
                ),
                child: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: Scaffold(
                    body: SafeArea(
                      child: ListView(
                        children: [
                          ShareListTile(share: fixture()),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: ShareContents(share: fixture()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Holiday.jpg'), findsNothing);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(ShareContents),
                  matching: find.text('SM'),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Photos'));
          await tester.pumpAndSettle();
          expect(find.text('Holiday.jpg'), findsOneWidget);
          expect(find.textContaining('2.0 KB'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/modernization/share-folder-${platform.name}-$dark-$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.byTooltip('Back to SM'));
          await tester.pumpAndSettle();
          expect(find.text('Holiday.jpg'), findsNothing);
        });
      }
    }
  }
}
