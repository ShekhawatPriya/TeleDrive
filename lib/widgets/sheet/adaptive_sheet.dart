import 'package:flutter/material.dart';
import '../adaptive_surface.dart';

/// One route contract, with an inset iOS material and a Material Android sheet.
/// The route owns keyboard avoidance, scrolling, drag dismissal and safe areas.
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
    showDragHandle: !ios,
    constraints: const BoxConstraints(maxWidth: 600),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) {
      final media = MediaQuery.of(context);
      final child = builder(context);
      final body = scrollBody ? SingleChildScrollView(child: child) : child;
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
          child: ios
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: AdaptiveSurface(
                    radius: 32,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
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
                          Flexible(child: body),
                        ],
                      ),
                    ),
                  ),
                )
              : body,
        ),
      );
    },
  );
}
