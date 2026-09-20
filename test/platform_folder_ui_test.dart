import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_fab.dart';
import 'package:flutter_m_fsdk/widgets/sheet/ios_action_group.dart';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_dialogs.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_action_sheet.dart';
import 'package:flutter_m_fsdk/features/drive/components/folder_editor.dart';
import 'package:flutter_m_fsdk/widgets/sheet/adaptive_sheet.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/modernization/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final family in [
      'Inter',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('add sheet $platform dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = platform;
          final theme = buildTheme(
            AppBrand.scheme(
              dark ? Brightness.dark : Brightness.light,
              highContrast: scale == 2,
            ),
          ).copyWith(platform: platform);
          debugDefaultTargetPlatformOverride = null;
          await tester.pumpWidget(
            ProviderScope(
              child: RepaintBoundary(
                key: const ValueKey('preview'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: theme.copyWith(
                    textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      highContrast: scale == 2,
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: const Scaffold(floatingActionButton: DriveFab()),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(DriveFab));
          await tester.pumpAndSettle();
          for (final label in [
            platform == TargetPlatform.iOS ? 'Upload' : 'Upload File',
            'Take Photo',
            'Create Folder',
          ]) {
            expect(find.text(label), findsOneWidget);
          }
          if (platform == TargetPlatform.iOS) {
            expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
            for (final row in find.byType(IosActionRow).evaluate()) {
              expect(
                tester.getSize(find.byWidget(row.widget)).height,
                greaterThanOrEqualTo(48),
              );
            }
            if (scale == 1) {
              expect(
                tester
                    .getSize(
                      find.byKey(const ValueKey('ios-action-sheet-surface')),
                    )
                    .height,
                lessThan(280),
              );
            }
          }
          await capture(tester, 'add-sheet-${platform.name}-$dark-$scale');
          await tester.ensureVisible(find.text('Create Folder'));
          await tester.tap(find.text('Create Folder'));
          await tester.pumpAndSettle();
          expect(find.byType(FolderEditor), findsOneWidget);
          if (platform == TargetPlatform.iOS) {
            expect(find.byTooltip('Cancel'), findsNothing);
            await tester.tapAt(const Offset(8, 80));
          } else {
            await tester.ensureVisible(find.byTooltip('Cancel'));
            await tester.tap(find.byTooltip('Cancel'));
          }
          await tester.pumpAndSettle();
          expect(find.byType(FolderEditor), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('folder create, rename and cancel $platform dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = platform;
        final theme = buildTheme(
          AppBrand.scheme(dark ? Brightness.dark : Brightness.light),
        ).copyWith(platform: platform);
        debugDefaultTargetPlatformOverride = null;
        String? result;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            result = await promptFolderName(context);
                          },
                          child: const Text('Open create'),
                        ),
                        TextButton(
                          onPressed: () async {
                            result = await promptFolderName(
                              context,
                              title: 'Rename folder',
                              initial: 'Travel',
                              confirmLabel: 'Save',
                            );
                          },
                          child: const Text('Open rename'),
                        ),
                        TextButton(
                          onPressed: () => showAdaptiveSheet<String>(
                            context: context,
                            builder: (_) => const DriveActionSheet(
                              title: 'Travel',
                              subtitle: 'Folder · 12 items',
                              folder: DriveFolder(
                                id: 'f',
                                name: 'Travel',
                                parentId: null,
                                modifiedAt: '',
                                createdAt: '',
                                recursiveFileCount: 12,
                                recursiveSize: 42000000,
                              ),
                              actions: [
                                SheetActionItem(
                                  id: 'share',
                                  label: 'Share',
                                  icon: Icons.share_outlined,
                                ),
                                SheetActionItem(
                                  id: 'rename',
                                  label: 'Rename',
                                  icon: Icons.edit_outlined,
                                ),
                                SheetActionItem(
                                  id: 'move',
                                  label: 'Move',
                                  icon: Icons.drive_file_move_outlined,
                                ),
                                SheetActionItem(
                                  id: 'star',
                                  label: 'Star',
                                  icon: Icons.star_outline,
                                ),
                                SheetActionItem(
                                  id: 'delete',
                                  label: 'Move to Trash',
                                  icon: Icons.delete_outline,
                                  destructive: true,
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Open actions'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open create'));
        await tester.pumpAndSettle();
        expect(find.byType(FolderEditor), findsOneWidget);
        if (platform == TargetPlatform.iOS) {
          expect(
            tester
                .widget<CupertinoButton>(
                  find.widgetWithText(CupertinoButton, 'Create'),
                )
                .onPressed,
            isNull,
          );
        } else {
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Create'),
                )
                .onPressed,
            isNull,
          );
        }
        await tester.enterText(find.byType(EditableText), '  Weekend plans  ');
        await tester.pumpAndSettle();
        await capture(
          tester,
          'folder-editor-${platform.name}-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(result, 'Weekend plans');
        await tester.tap(find.text('Open rename'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Travel',
        );
        await tester.enterText(find.byType(EditableText), 'Summer');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(result, 'Summer');
        await tester.tap(find.text('Open create'));
        await tester.pumpAndSettle();
        if (platform == TargetPlatform.iOS) {
          await tester.tapAt(const Offset(8, 80));
        } else {
          await tester.tap(find.byTooltip('Cancel'));
        }
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.tap(find.text('Open actions'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'folder-actions-${platform.name}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('folder editor fits keyboard and 200 percent text $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      debugDefaultTargetPlatformOverride = platform;
      final theme = buildTheme(
        AppBrand.scheme(Brightness.light),
      ).copyWith(platform: platform);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => promptFolderName(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Long folder name');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(FolderEditor), findsNothing);
    });
  }
}
