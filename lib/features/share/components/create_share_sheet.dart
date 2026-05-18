import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../models/share_models.dart';
import '../share_controller.dart';
import 'share_expiry_picker.dart';
import 'share_permission_picker.dart';
import 'share_result_view.dart';

class CreateShareSheet extends ConsumerStatefulWidget {
  const CreateShareSheet({required this.items, this.title, super.key});

  final List<ShareItemRequest> items;
  final String? title;

  @override
  ConsumerState<CreateShareSheet> createState() => _CreateShareSheetState();
}

class _CreateShareSheetState extends ConsumerState<CreateShareSheet> {
  SharePermission _permission = SharePermission.preview;
  ShareExpiryOption _expiry = ShareExpiryOption.day1;
  bool _busy = false;
  String? _error;
  Share? _result;

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: result != null
            ? ShareResultView(
                share: result,
                onCopy: _copyLink,
                onShare: _shareSheet,
                onDone: () => Navigator.pop(context),
              )
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title ?? _defaultTitle(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.items.length} item${widget.items.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SharePermissionPicker(
          value: _permission,
          onChanged: (v) => setState(() => _permission = v),
        ),
        const SizedBox(height: 20),
        ShareExpiryPicker(
          value: _expiry,
          onChanged: (v) => setState(() => _expiry = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create link'),
        ),
      ],
    );
  }

  String _defaultTitle() {
    final hasFolder = widget.items.any((i) => i.type == ShareItemType.folder);
    return hasFolder ? 'Share folder' : 'Share';
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final share = await ref
          .read(shareControllerProvider)
          .createShare(
            items: widget.items,
            permission: _permission,
            expiresAt: _expiry.toExpiry(),
          );
      if (!mounted) return;
      setState(() => _result = share);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
