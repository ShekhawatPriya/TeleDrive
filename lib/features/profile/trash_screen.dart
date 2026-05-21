import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../drive/components/drive_dialogs.dart';
import '../drive/drive_controller.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  bool _loading = true;
  List<DriveFile> _files = const [];
  List<DriveFolder> _folders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(driveRepositoryProvider);
      final results = await Future.wait([
        repo.listTrashFiles(),
        repo.listTrashFolders(),
      ]);
      if (!mounted) return;
      setState(() {
        _files = results[0] as List<DriveFile>;
        _folders = results[1] as List<DriveFolder>;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Trash.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = !_loading && _files.isEmpty && _folders.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Trash'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Items here still exist in Telegram storage until you delete them forever.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error))
            else if (empty)
              Padding(
                padding: const EdgeInsets.only(top: 72),
                child: Column(
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 56,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Trash is empty', style: theme.textTheme.titleMedium),
                  ],
                ),
              )
            else ...[
              for (final folder in _folders)
                _TrashTile(
                  title: folder.name,
                  subtitle: 'Folder',
                  icon: Icons.folder_outlined,
                  onRestore: () => _restoreFolder(folder.id),
                  onPurge: () => _purgeFolder(folder.id),
                ),
              for (final file in _files)
                _TrashTile(
                  title: file.name,
                  subtitle: formatFileSize(file.size),
                  icon: _fileIcon(file.kind),
                  onRestore: () => _restoreFile(file.id),
                  onPurge: () => _purgeFile(file.id),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restoreFile(String id) async {
    await ref.read(driveControllerProvider).restoreFile(id);
    await _load();
  }

  Future<void> _restoreFolder(String id) async {
    await ref.read(driveControllerProvider).restoreFolder(id);
    await _load();
  }

  Future<void> _purgeFile(String id) async {
    final ok = await confirmDelete(context, 1, trashEnabled: false);
    if (!ok || !mounted) return;
    await ref.read(driveControllerProvider).purgeFile(id);
    await _load();
  }

  Future<void> _purgeFolder(String id) async {
    final ok = await confirmDelete(context, 1, trashEnabled: false);
    if (!ok || !mounted) return;
    await ref.read(driveControllerProvider).purgeFolder(id);
    await _load();
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRestore,
    required this.onPurge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Restore',
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
            ),
            IconButton(
              tooltip: 'Delete forever',
              onPressed: onPurge,
              color: scheme.error,
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        ),
        titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

IconData _fileIcon(FileKind kind) {
  return switch (kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.video => Icons.play_circle_outline,
    FileKind.audio => Icons.audiotrack,
    FileKind.pdf => Icons.picture_as_pdf,
    FileKind.folder => Icons.folder_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}
