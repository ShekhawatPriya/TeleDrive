import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/country_picker.dart';
import 'package:flutter_m_fsdk/features/auth/country_data.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/drive/move_destination_sheet.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/sheet/adaptive_sheet.dart';
import 'platform_folder_ui_test.dart' as previews;

class _Folders implements DriveRepository {
  @override
  Future<
    ({List<DriveFolder> folders, String? nextCursor, List<DriveFolder> path})
  >
  listFolderChildren({
    String? parentId,
    int limit = 200,
    String? cursor,
  }) async => (
    folders: parentId == null
        ? const [
            DriveFolder(
              id: 'travel',
              name: 'Travel',
              parentId: null,
              modifiedAt: '',
              createdAt: '',
            ),
          ]
        : const <DriveFolder>[],
    nextCursor: null,
    path: const <DriveFolder>[],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    for (final family in [
      'Inter',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF Pro Text',
      '.SF Pro Display',
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
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('iOS pickers dismiss and choose dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final theme = buildTheme(
          AppBrand.scheme(
            dark ? Brightness.dark : Brightness.light,
            highContrast: scale == 2,
          ),
        );
        debugDefaultTargetPlatformOverride = null;
        Object? result = 'pending';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [driveRepositoryProvider.overrideWithValue(_Folders())],
            child: RepaintBoundary(
              key: const ValueKey('preview'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  platform: TargetPlatform.iOS,
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
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        TextButton(
                          onPressed: () async {
                            result = await showCountryPicker(context);
                          },
                          child: const Text('Country'),
                        ),
                        TextButton(
                          onPressed: () async {
                            result = await showAdaptiveSheet<String>(
                              context: context,
                              scrollBody: false,
                              builder: (_) => const MoveDestinationSheet(
                                title: 'Move item',
                              ),
                            );
                          },
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final picker in ['Country', 'Move']) {
          await tester.tap(find.text(picker));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close'), findsNothing);
          await previews.capture(
            tester,
            '${picker.toLowerCase()}-sheet-iOS-${dark ? 'dark' : 'light'}-$scale',
          );
          final handle = find.bySemanticsLabel('Dismiss sheet');
          await tester.fling(handle, const Offset(0, 600), 1500);
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(
            find.byKey(const ValueKey('ios-action-sheet-surface')),
            findsNothing,
          );
        }
        await tester.tap(find.text('Move'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Travel'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsOneWidget);
        await tester.tap(find.text('Move here'));
        await tester.pumpAndSettle();
        expect(result, 'travel');
        await tester.tap(find.text('Country'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.enterText(find.byType(EditableText), 'United Kingdom');
        await tester.pumpAndSettle();
        final country = find.widgetWithText(ListTile, 'United Kingdom');
        await tester.ensureVisible(country);
        await tester.pumpAndSettle();
        await tester.tap(country);
        await tester.pumpAndSettle();
        expect(
          result,
          isA<Country>().having(
            (country) => country.dialCode,
            'dial code',
            '+44',
          ),
        );
        expect(find.text('Choose a country'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
