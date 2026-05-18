import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../models/share_models.dart';
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
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share failed',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Unknown error.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            setState(() {
              _busy = true;
              _error = null;
            });
            _create();
          },
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
