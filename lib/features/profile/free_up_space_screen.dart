import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import 'cache_controller.dart';

part 'free_up_space/free_up_space_components.dart';
part 'free_up_space/free_up_space_dialog.dart';
part 'free_up_space/free_up_space_illustration.dart';

class FreeUpSpaceScreen extends ConsumerStatefulWidget {
  const FreeUpSpaceScreen({super.key});

  @override
  ConsumerState<FreeUpSpaceScreen> createState() => _FreeUpSpaceScreenState();
}

class _FreeUpSpaceScreenState extends ConsumerState<FreeUpSpaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cacheControllerProvider).refreshCacheStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canFree = formatFileSize(cache.totalSize);
    final isClearing = cache.isClearing;
    final totalSize = cache.totalSize;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: CustomPaint(
                  size: const Size(168, 220),
                  painter: _FreeUpSpaceIllustrationPainter(),
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Free up space on this device',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _FreeUpInfoRow(
                icon: Icons.cloud_done_outlined,
                titleWidget: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'These items are already safely backed up in your chosen quality. ',
                      ),
                      TextSpan(
                        text: 'Learn more',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showFreeUpSpaceInfoDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _FreeUpInfoRow(
                icon: Icons.mobile_friendly_rounded,
                titleWidget: Text(
                  'You can still view them at any time in Telegram Drive.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: FilledButton(
          onPressed: (isClearing || totalSize == 0)
              ? null
              : () async {
                  try {
                    await ref.read(cacheControllerProvider).clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text('Successfully freed up space!'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: scheme.inverseSurface,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to clear space: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            elevation: 0,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: isClearing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Clearing space...'),
                  ],
                )
              : Text(
                  totalSize == 0 ? 'Space is already free' : 'Free up $canFree',
                ),
        ),
      ),
    );
  }
}
