import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../models/share_models.dart';
import '../drive/components/drive_dialogs.dart';
import 'components/share_detail_body.dart';
import 'share_controller.dart';

class ShareDetailScreen extends ConsumerStatefulWidget {
  const ShareDetailScreen({required this.shareId, super.key});

  final String shareId;

  @override
  ConsumerState<ShareDetailScreen> createState() => _ShareDetailScreenState();
}

class _ShareDetailScreenState extends ConsumerState<ShareDetailScreen> {
  Share? _share;
  ShareStats? _stats;
  final List<ShareAccess> _accesses = [];
  String? _accessCursor;
  bool _accessesLoading = false;
  bool _accessesHasMore = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = ref.read(shareControllerProvider);
    try {
      final results = await Future.wait([
        controller.getShare(widget.shareId),
        controller.getStats(widget.shareId),
      ]);
      if (!mounted) return;
      setState(() {
        _share = results[0] as Share;
        _stats = results[1] as ShareStats;
      });
      await _loadMoreAccesses();
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<void> _loadMoreAccesses() async {
    if (_accessesLoading || !_accessesHasMore) return;
    setState(() => _accessesLoading = true);
    try {
      final result = await ref
          .read(shareControllerProvider)
          .listAccesses(widget.shareId, cursor: _accessCursor);
      if (!mounted) return;
      setState(() {
        _accesses.addAll(result.accesses);
        _accessCursor = result.nextCursor;
        _accessesHasMore = result.nextCursor != null;
      });
    } catch (_) {
      // silent — keep what we already have
    } finally {
      if (mounted) setState(() => _accessesLoading = false);
    }
  }

  Future<void> _copyLink() async {
    final share = _share;
    if (share == null) return;
    await Clipboard.setData(ClipboardData(text: share.url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareLink() async {
    final share = _share;
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

  Future<void> _revoke() async {
    final share = _share;
    if (share == null) return;
    final ok = await confirmAction(
      context,
      title: 'Revoke share?',
      message:
          'The link will stop working immediately and cannot be restored.',
      confirmLabel: 'Revoke',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareControllerProvider).revokeShare(share.id);
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final share = _share;
    return Scaffold(
      appBar: AppBar(
        title: Text(share?.primaryName ?? 'Share'),
        actions: [
          IconButton(
            tooltip: 'Revoke',
            onPressed: share == null || _busy ? null : _revoke,
            icon: const Icon(Icons.link_off_outlined),
          ),
        ],
      ),
      body: share == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : ShareDetailBody(
              share: share,
              stats: _stats,
              accesses: _accesses,
              accessesHasMore: _accessesHasMore,
              accessesLoading: _accessesLoading,
              onLoadMore: _loadMoreAccesses,
              onCopy: _copyLink,
              onShare: _shareLink,
            ),
    );
  }
}
