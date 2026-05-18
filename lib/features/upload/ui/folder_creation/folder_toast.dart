import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../components/upload_progress_bar.dart';
import 'folder_toast_controller.dart';

class FolderToast extends StatelessWidget {
  const FolderToast({required this.state, super.key});
  final FolderToastState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final accent = dark ? AppColors.coral : AppColors.terracotta;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: !state.visible
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : Container(
              key: ValueKey('toast-${state.label}-${state.isError}'),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : AppColors.ivory,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: dark ? const Color(0xff3d3d3a) : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.isError)
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: scheme.error,
                            )
                          else
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              state.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: state.isError
                                    ? scheme.error
                                    : scheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!state.isError)
                      const UploadProgressBar(
                        value: 0,
                        height: 1.6,
                        indeterminate: true,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
