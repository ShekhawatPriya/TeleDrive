import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../core/theme/app_theme.dart';
import '../../../models/share_models.dart';
import '../../drive/components/drive_dialogs.dart';
import '../../profile/app_settings_controller.dart';
import '../share_controller.dart';
import 'share_result_view.dart';

class CreateShareSheet extends ConsumerStatefulWidget {
  const CreateShareSheet({required this.items, super.key});

  final List<ShareItemRequest> items;

  @override
  ConsumerState<CreateShareSheet> createState() => _CreateShareSheetState();
}

class _CreateShareSheetState extends ConsumerState<CreateShareSheet> {
  bool _busy = true;
  String? _error;
  Share? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    if (ref.read(appSettingsControllerProvider).state.confirmPublicShares) {
      final ok = await confirmAction(
        context,
        title: 'Create public link?',
        message:
            'Anyone with this link may be able to access the shared file or folder depending on the share rules.',
        confirmLabel: 'Create link',
      );
      if (!ok) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }
    try {
      final share = await ref
          .read(shareControllerProvider)
          .createShare(items: widget.items);
      if (!mounted) return;
      setState(() {
        _result = share;
        _busy = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = _readableError(err);
        _busy = false;
      });
    }
  }

  String _readableError(Object err) {
    final s = err.toString();
    if (s.contains('file_not_shareable')) {
      return 'One of these files is not ready to share yet.';
    }
    return 'Could not create share. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final result = _result;
    if (result != null) {
      return ShareResultView(
        share: result,
        onCopy: _copyLink,
        onShare: _shareSheet,
        onDone: () => Navigator.pop(context),
      );
    }
    if (_busy) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share failed', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(_error ?? 'Unknown error.', style: TextStyle(color: scheme.error)),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () {
            setState(() {
              _busy = true;
              _error = null;
            });
            _create();
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Future<void> _copyLink() async {
    final share = _result;
    if (share == null) return;
    await Clipboard.setData(ClipboardData(text: share.url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareSheet() async {
    final share = _result;
    if (share == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    await share_plus.Share.share(
      share.url,
      subject: share.primaryName ?? 'TeleDrive share',
      sharePositionOrigin: origin,
    );
  }
}
