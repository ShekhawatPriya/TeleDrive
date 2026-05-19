import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'folder_toast_controller.dart';

/// Compact M3 status pill shown while a folder is being created from the FAB
/// sheet. Mirrors the surface-container-high look of [UploadCollapsedBar] so
/// both bottom-anchored pills feel like one family.
class FolderToast extends StatelessWidget {
  const FolderToast({required this.state, super.key});
  final FolderToastState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = state.isError;

    final surfaceColor = scheme.surfaceContainerHigh;
    final labelColor = isError ? scheme.onErrorContainer : scheme.onSurface;
    final dotBg = isError ? scheme.errorContainer : scheme.primaryContainer;
    final dotFg = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;

    return AnimatedSwitcher(
      duration: AppDurations.short3,
      switchInCurve: AppEasing.standardDecelerate,
      switchOutCurve: AppEasing.standardAccelerate,
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: anim, curve: AppEasing.standardDecelerate),
        );
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: !state.visible
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : Material(
              key: ValueKey('toast-${state.label}-$isError'),
              color: surfaceColor,
              surfaceTintColor: scheme.surfaceTint,
              shadowColor: scheme.shadow,
              elevation: AppElevation.level3,
              borderRadius: AppRadii.lgR,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: dotBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: isError
                            ? Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: dotFg,
                              )
                            : SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    dotFg,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          state.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: labelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
