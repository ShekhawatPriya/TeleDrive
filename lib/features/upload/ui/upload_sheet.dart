import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../upload_controller.dart';
import '../upload_models.dart';
import 'components/upload_card.dart';
import 'components/upload_row_transition.dart';
import 'components/upload_sheet_header.dart';
import 'components/upload_status_ring.dart';

/// The header and lazy list share a scroll controller, including sheet drags.
class UploadSheet extends ConsumerStatefulWidget {
  const UploadSheet({
    required this.onMinimize,
    this.bottomInset = 0,
    super.key,
  });
  final double bottomInset;
  final VoidCallback onMinimize;

  @override
  ConsumerState<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<UploadSheet> {
  final _compactContentKey = GlobalKey();
  double? _compactHeight;

  /// Displayed rows: the queue's ids plus rows still animating out.
  List<String> _rows = const [];
  final Set<String> _departing = {};

  /// Ids added after the panel opened; they spring in instead of appearing.
  final Set<String> _entering = {};
  int? _reconciledVersion;

  /// Merges the queue into the displayed rows. Removed ids stay in place as
  /// departing rows until their exit finishes; new ids take their queue
  /// position. The first snapshot appears with the panel, unanimated.
  void _reconcile(UploadItemIdsSnapshot snapshot) {
    if (_reconciledVersion == snapshot.version) return;
    final first = _reconciledVersion == null;
    _reconciledVersion = snapshot.version;
    final ids = snapshot.ids;
    final current = ids.toSet();
    final shown = _rows.toSet();
    // Clearing the whole queue closes the panel; nothing to animate.
    if (ids.isEmpty) {
      _rows = const [];
      _departing.clear();
      _entering.clear();
      return;
    }
    final merged = <String>[];
    final placed = <String>{};
    var next = 0;
    void place(String id) {
      if (placed.add(id)) merged.add(id);
    }

    for (final row in _rows) {
      if (!current.contains(row)) {
        _departing.add(row);
        place(row);
        continue;
      }
      while (next < ids.length && ids[next] != row) {
        place(ids[next++]);
      }
      if (next < ids.length) {
        place(ids[next++]);
      }
    }
    while (next < ids.length) {
      place(ids[next++]);
    }
    if (!first) {
      _entering.addAll(current.where((id) => !shown.contains(id)));
    }
    // An id that returns while departing is live again.
    _departing.removeWhere(current.contains);
    _rows = merged;
  }

  void _handleExited(String id) {
    if (!mounted || !_departing.remove(id)) return;
    setState(() => _rows = _rows.where((row) => row != id).toList());
    _measureCompactContent();
  }

  void _handleEntered(String id) {
    _entering.remove(id);
    _measureCompactContent();
  }

  /// One row with its leading separator, so both enter and leave together.
  Widget _row(int index, Widget Function() separator, {EdgeInsets? padding}) {
    final id = _rows[index];
    Widget card = UploadCard(key: ValueKey(id), localId: id);
    if (padding != null) card = Padding(padding: padding, child: card);
    return UploadRowTransition(
      key: ValueKey('row-$id'),
      animateIn: _entering.contains(id),
      departing: _departing.contains(id),
      onEntered: () => _handleEntered(id),
      onExited: () => _handleExited(id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (index > 0) separator(), card],
      ),
    );
  }

  void _measureCompactContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _compactContentKey.currentContext?.size?.height;
      if (height != null && (height - (_compactHeight ?? 0)).abs() > .5) {
        setState(() => _compactHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(
      uploadControllerProvider.select((c) => c.summary),
    );
    final idsSnapshot = ref.watch(
      uploadControllerProvider.select((c) => c.itemIdsSnapshot),
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;

    ref.listen<UploadController>(uploadControllerProvider, (previous, next) {
      if (!next.sheetVisible || next.items.isEmpty) widget.onMinimize();
    });
    _reconcile(idsSnapshot);
    final rowCount = _rows.length;
    final compact = rowCount <= 2;
    if (compact) _measureCompactContent();

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Minimize uploads',
          onDismiss: widget.onMinimize,
          child: const SheetDragHandle(),
        ),
        UploadSheetHeader(
          summary: summary,
          onMinimize: widget.onMinimize,
          onRetry: () => ref.read(uploadControllerProvider).confirmUpload(),
          onUseMobileData: () =>
              ref.read(uploadControllerProvider).enableMobileDataUploads(),
        ),
        if (ios) _IosFilesLabel(count: idsSnapshot.ids.length),
        if (summary.waitingForWifi && !ios)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ios
                  ? CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(48, 48),
                      onPressed: () => ref
                          .read(uploadControllerProvider)
                          .enableMobileDataUploads(),
                      child: Text(
                        'Use mobile data',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => ref
                          .read(uploadControllerProvider)
                          .enableMobileDataUploads(),
                      icon: const Icon(Icons.network_cell_rounded),
                      label: const Text('Use mobile data'),
                    ),
            ),
          ),
      ],
    );
    Widget separator() => ios
        ? Divider(
            height: 1,
            thickness: MediaQuery.highContrastOf(context) ? 1 : .5,
            // Aligned with the filename, as in an inset grouped list.
            indent: 68,
            color: scheme.outlineVariant,
          )
        : const SizedBox(height: 8);
    final panel = iosUploadPanelColors(scheme);
    final cardShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(26),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final initial = compact
            ? ((_compactHeight ?? 360) / constraints.maxHeight).clamp(.22, .92)
            : MediaQuery.textScalerOf(context).scale(17) > 24
            ? .92
            : .62;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: initial,
          minChildSize: .16,
          maxChildSize: .92,
          snap: true,
          snapSizes: [initial, if (initial < .92) .92],
          builder: (context, controller) {
            final content = Material(
              type: MaterialType.transparency,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  if (compact)
                    SliverToBoxAdapter(
                      child: Column(
                        key: _compactContentKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          header,
                          if (ios)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: panel.card,
                                  shape: cardShape,
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < rowCount; i++)
                                      _row(i, separator),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < rowCount; i++)
                              _row(
                                i,
                                separator,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                          SizedBox(height: 16 + widget.bottomInset),
                        ],
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: header),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        20 + widget.bottomInset,
                      ),
                      sliver: DecoratedSliver(
                        decoration: ios
                            ? ShapeDecoration(
                                color: panel.card,
                                shape: cardShape,
                              )
                            : const BoxDecoration(),
                        sliver: SliverList.builder(
                          itemCount: rowCount,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;
                            final index = _rows.indexOf(
                              key.value.replaceFirst('row-', ''),
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (_, i) => _row(i, separator),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
            // The iOS shell extends this surface behind native navigation.
            // Its measured navigation inset belongs inside scrollable content.
            if (ios) {
              return ClipRSuperellipse(
                key: const ValueKey('upload-panel-surface'),
                borderRadius: AppRadii.sheetTop,
                child: ColoredBox(color: panel.page, child: content),
              );
            }
            return Material(
              key: const ValueKey('upload-panel-surface'),
              color: scheme.surfaceContainerLow,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.sheetTop,
              ),
              child: content,
            );
          },
        );
      },
    );
  }
}

/// Grouped-list section label above the files card.
class _IosFilesLabel extends StatelessWidget {
  const _IosFilesLabel({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        count == 1 ? '1 FILE' : '$count FILES',
        style: TextStyle(
          fontSize: 13,
          letterSpacing: -0.08,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
