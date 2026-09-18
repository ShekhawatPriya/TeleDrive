// Simulator-only fixture. All actions stay local; no live account is loaded.
import 'dart:io';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/features/share/share_flow.dart';
import 'package:flutter_m_fsdk/features/share/file_copy_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_details_sheet.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_pager.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_stage.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_top_bar.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

void main() {
  final auth = _FixtureAuth();
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => auth),
        fileCopyShareServiceProvider.overrideWithValue(
          FileCopyShareService(
            stage: (source, file, name, token) => stageOriginalForSharing(
              source,
              file,
              name,
              token,
              backend: 'fixture',
              userId: 1,
              telegramId: 10,
            ),
            auth: auth,
            download: (file, _, __) async => File(file.previewUrl!),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(
          AppBrand.scheme(Brightness.dark),
        ).copyWith(platform: TargetPlatform.iOS),
        home: const _Preview(),
      ),
    ),
  );
}

class _Preview extends ConsumerStatefulWidget {
  const _Preview();
  @override
  ConsumerState<_Preview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<_Preview> {
  final stage = GlobalKey<PhotoViewerStageState>();
  double? aspect;
  bool zoomed = false;
  String lastAction = 'Photo viewer fixture';
  DriveFile file = DriveFile(
    id: 'fixture',
    name: 'Alpine afternoon.jpg',
    kind: FileKind.image,
    size: File(const String.fromEnvironment('PHOTO_PREVIEW_PATH')).lengthSync(),
    mimeType: 'image/jpeg',
    modifiedAt: '2026-09-17',
    createdAt: '2026-09-17',
    parentId: null,
    starred: false,
    previewUrl: File(const String.fromEnvironment('PHOTO_PREVIEW_PATH')).path,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: PhotoViewerStage(
      key: stage,
      mediaAspectRatio: aspect,
      mediaZoomed: zoomed,
      onDetailsChanged: () => setState(() {}),
      media: PhotoViewerPager(
        files: [file],
        initialIndex: 0,
        onPageChanged: (_) {},
        onTapMedia: () {},
        onDimensions: (_, size) =>
            setState(() => aspect = size.width / size.height),
        onZoomChanged: (_, value) => setState(() => zoomed = value),
      ),
      header: ref.watch(shareFlowStateProvider).busy
          ? const SizedBox.shrink()
          : SafeArea(
              child: Text(
                lastAction,
                style: const TextStyle(color: Colors.white),
              ),
            ),
      detailsBuilder: (scroll) => PhotoDetailsSheet(
        file: file,
        folderName: null,
        scrollController: scroll,
        integrated: true,
      ),
      footer: ref.watch(shareFlowStateProvider).busy
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 8,
                ),
                child: PhotoViewerActions(
                  file: file,
                  infoSelected: stage.currentState?.isOpen ?? false,
                  onStar: () => setState(
                    () => file = file.copyWith(starred: !file.starred),
                  ),
                  onInfo: () => stage.currentState?.toggle(),
                  onDownload: () {},
                  onShare: () => openItemShare(context, ref, files: [file]),
                  onDelete: () =>
                      setState(() => lastAction = 'Fixture delete tapped'),
                ),
              ),
            ),
    ),
  );
}

class _FixtureAuth extends ChangeNotifier implements AuthController {
  @override
  AuthUser get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Fixture');
  @override
  String get token => 'fixture';
  @override
  bool get switchingAccount => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
