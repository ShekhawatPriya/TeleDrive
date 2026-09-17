import 'package:flutter/material.dart';
import '../adaptive_surface.dart';

/// One clipping boundary on iOS, inset from both the screen and home indicator.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollBody = true,
}) {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: ios ? Colors.transparent : null,
    elevation: ios ? 0 : null,
    shape: ios ? const RoundedRectangleBorder() : null,
    clipBehavior: ios ? Clip.none : null,
    showDragHandle: !ios,
    constraints: const BoxConstraints(maxWidth: 600),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) {
      final media = MediaQuery.of(context);
      final child = builder(context);
      final body = scrollBody ? SingleChildScrollView(child: child) : child;
      if (!ios)
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (media.size.height -
                          media.viewInsets.bottom -
                          media.padding.top -
                          24)
                      .clamp(80, 1000),
            ),
            child: body,
          ),
        );
      return LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - 24,
                maxHeight:
                    (constraints.maxHeight -
                            media.viewInsets.bottom -
                            media.padding.bottom -
                            24)
                        .clamp(0, 1000),
              ),
              child: AdaptiveSurface(
                key: const ValueKey('ios-action-sheet-surface'),
                radius: 28,
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expose dismissal to assistive technology without adding
                      // a second visible control beside the drag indicator.
                      Semantics(
                        label: 'Dismiss sheet',
                        onDismiss: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Flexible(child: body),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
