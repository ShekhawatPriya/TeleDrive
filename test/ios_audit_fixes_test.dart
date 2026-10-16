import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/navigation/root_navigator.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/utils/app_haptics.dart';
import 'package:flutter_m_fsdk/core/utils/file_type_detector.dart';
import 'package:flutter_m_fsdk/features/drive/components/folder_editor.dart';
import 'package:flutter_m_fsdk/features/profile/widgets/ios_appearance_picker.dart';
import 'package:flutter_m_fsdk/widgets/app_message.dart';
import 'package:flutter_m_fsdk/widgets/file_name_text.dart';
import 'package:flutter_m_fsdk/widgets/ios/ios_browse.dart';

/// Regression coverage for the iOS design-audit fixes: Files-style middle
/// truncation, toast feedback instead of snackbars, haptics, springs, the
/// icon grid, the plain appearance list and the folder sheet bar.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<BuildContext> pump(
    WidgetTester tester,
    Widget child, {
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The theme captures the platform; the global override must be cleared
    // before the test ends.
    debugDefaultTargetPlatformOverride = platform;
    final theme = buildTheme(AppBrand.scheme(Brightness.light));
    debugDefaultTargetPlatformOverride = null;
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return child;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  group('FileNameText', () {
    const style = TextStyle(fontSize: 15);
    String? fit(String name, double width) => FileNameText.fit(
      name,
      style: style,
      maxWidth: width,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
    );

    test('keeps the extension and the end of the name', () {
      final result = fit('A weekend in the mountains.jpg', 250);
      expect(result, isNotNull);
      expect(result, contains('…'));
      expect(result, endsWith('ains.jpg'));
      expect(result, startsWith('A weeke'));
    });

    test('leaves names that fit unchanged', () {
      expect(fit('Budget.xlsx', 400), isNull);
    });

    testWidgets('announces the full name', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const Center(
          child: SizedBox(
            width: 120,
            child: FileNameText('Quarterly board update final.pdf'),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Quarterly board update final.pdf'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('AppMessenger', () {
    testWidgets('iOS shows the rounded toast, not a snackbar', (tester) async {
      final context = await pump(tester, const SizedBox());
      showAppMessage(context, 'Share link revoked');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('premium-toast-card')), findsOneWidget);
      expect(find.text('Share link revoked'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Android keeps the Material snackbar', (tester) async {
      final context = await pump(
        tester,
        const SizedBox(),
        platform: TargetPlatform.android,
      );
      showAppMessage(context, 'Share link revoked');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-toast-card')), findsNothing);
    });
  });

  group('AppHaptics', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String);
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('iOS gives selection, success and warning feedback', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppHaptics.selection();
      AppHaptics.success();
      AppHaptics.warning();
      expect(calls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.warningNotification',
      ]);
    });

    test('Android behavior is unchanged', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppHaptics.selection();
      AppHaptics.success();
      expect(calls, isEmpty);
    });
  });

  test('iOS spring starts at rest, settles at the end, barely overshoots', () {
    const curve = IosSpringCurve();
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    expect(curve.transform(.9), closeTo(1, .01));
    var peak = 0.0;
    for (var t = 0.0; t <= 1; t += .01) {
      peak = peak > curve.transform(t) ? peak : curve.transform(t);
    }
    expect(peak, lessThan(1.03));
    const nearlyCritical = IosSpringCurve(damping: .95);
    for (var t = 0.0; t <= 1; t += .01) {
      expect(nearlyCritical.transform(t), lessThanOrEqualTo(1.001));
    }
  });

  testWidgets('iOS file grid uses at least three Files-style columns', (
    tester,
  ) async {
    late SliverGridDelegate delegate;
    await pump(
      tester,
      Builder(
        builder: (context) {
          delegate = IosBrowse.fileGrid(context);
          return const SizedBox();
        },
      ),
    );
    final grid = delegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(grid.crossAxisCount, 3);
    expect(grid.mainAxisExtent, greaterThan(150));
  });

  testWidgets('appearance options are plain rows with one checkmark', (
    tester,
  ) async {
    await pump(
      tester,
      IosAppearancePicker(mode: ThemeMode.system, onChanged: (_) {}),
    );
    expect(find.byIcon(CupertinoIcons.sun_max_fill), findsNothing);
    expect(find.byIcon(CupertinoIcons.moon_fill), findsNothing);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('iOS folder editor uses a Cancel / title / Create bar', (
    tester,
  ) async {
    String? result = 'unset';
    final context = await pump(tester, const SizedBox());
    final future = showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => const ColoredBox(
        color: Colors.white,
        child: FolderEditor(title: 'New folder', confirmLabel: 'Create'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Folder'), findsOneWidget);
    expect(find.widgetWithText(CupertinoButton, 'Cancel'), findsOneWidget);
    expect(find.byType(CupertinoButton).evaluate().length, 2);
    expect(
      tester
          .widget<CupertinoButton>(
            find.widgetWithText(CupertinoButton, 'Create'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(EditableText), 'Trips');
    await tester.pump();
    await tester.tap(find.text('Create'));
    result = await future;
    expect(result, 'Trips');
  });

  test('empty storage reads Zero KB', () {
    expect(formatStorageSize(0), 'Zero KB');
    expect(formatStorageSize(2048), '2.0 KB');
  });
}
