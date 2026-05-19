import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../components/upload_progress_bar.dart';
import 'folder_toast_controller.dart';

/// Lightweight toast (M3 snackbar-style surface) shown while a folder is being
/// created from the FAB sheet.
class FolderToast extends StatelessWidget {
  const FolderToast({required this.state, super.key});
  final FolderToastState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = state.isError ? scheme.onErrorContainer : scheme.onSurface;
    final bg = state.isError
        ? scheme.errorContainer
        : scheme.inverseSurface;
    final fgOnBg = state.isError ? fg : scheme.onInverseSurface;

    return AnimatedSwitcher(
      duration: AppDurations.short3,
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: AppEasing.standardDecelerate));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: !state.visible
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : Material(
              key: ValueKey('toast-${state.label}-${state.isError}'),
              color: bg,
              surfaceTintColor: scheme.surfaceTint,
              shadowColor: scheme.shadow,
              elevation: AppElevation.level3,
              borderRadius: AppRadii.xsR,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm,
                          AppSpacing.md, AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.isError)
                            Icon(Icons.error_outline_rounded,
                                size: 18, color: fgOnBg)
                          else
                            SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(fgOnBg),
                              ),
                            ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              state.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: fgOnBg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!state.isError)
                      const UploadProgressBar(
                        value: 0,
                        height: 2,
                        indeterminate: true,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
