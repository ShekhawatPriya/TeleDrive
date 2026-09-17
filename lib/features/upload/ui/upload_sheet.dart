import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../upload_controller.dart';
import 'components/upload_card.dart';
import 'components/upload_sheet_header.dart';

/// A persistent panel belongs to the current scaffold, keeping its navigation
/// visible and interactive. Scaffold supplies the actual navigation clearance.
Future<void> showUploadPanel(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  final scaffold = Scaffold.of(context);
  final bottomInset = scaffold.widget.bottomNavigationBar == null
      ? MediaQuery.viewPaddingOf(scaffold.context).bottom
      : 0.0;
  late PersistentBottomSheetController panel;
  panel = scaffold.showBottomSheet(
    (context) =>
        UploadSheet(onMinimize: () => panel.close(), bottomInset: bottomInset),
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    enableDrag: false,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 600),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
  );
  return panel.closed;
}

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
    final compact = idsSnapshot.ids.length <= 2;
    if (compact) _measureCompactContent();

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Minimize uploads',
          onDismiss: widget.onMinimize,
          child: const SheetDragHandle(),
        ),
        UploadSheetHeader(summary: summary),
        if (summary.waitingForWifi)
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
            indent: 72,
            endIndent: 20,
            color: scheme.outlineVariant,
          )
        : const SizedBox(height: 8);

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
                          for (var i = 0; i < idsSnapshot.ids.length; i++) ...[
                            if (i > 0) separator(),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ios ? 0 : 16,
                              ),
                              child: UploadCard(
                                key: ValueKey(idsSnapshot.ids[i]),
                                localId: idsSnapshot.ids[i],
                              ),
                            ),
                          ],
                          SizedBox(height: 16 + widget.bottomInset),
                        ],
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: header),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        ios ? 0 : 16,
                        0,
                        ios ? 0 : 16,
                        20 + widget.bottomInset,
                      ),
                      sliver: SliverList.separated(
                        itemCount: idsSnapshot.ids.length,
                        separatorBuilder: (_, __) => separator(),
                        itemBuilder: (_, i) => UploadCard(
                          key: ValueKey(idsSnapshot.ids[i]),
                          localId: idsSnapshot.ids[i],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
            // Edge attached above navigation; safe-area clearance is supplied by
            // the host once, never as a floating gap below the sheet surface.
            if (ios) {
              return ClipRSuperellipse(
                key: const ValueKey('upload-panel-surface'),
                borderRadius: AppRadii.sheetTop,
                child: ColoredBox(
                  color: scheme.surfaceContainerLow,
                  child: content,
                ),
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
