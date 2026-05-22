import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import 'cache_controller.dart';

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

  void _showLearnMoreDialog(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Backup & Space'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How does Free Up Space work?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Free up space deletes the local cache files (thumbnails, preview files, and cached downloads) stored on this device. These files have already been safely uploaded to your Telegram Cloud Drive.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Will my files be deleted from Telegram?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No. Your files remain completely safe in your Telegram Cloud Drive. You can stream, preview, or download them again at any time within TeleDrive.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
        top: false, // Let AppBar handle top safe area
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
                          ..onTap = () => _showLearnMoreDialog(context),
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

class _FreeUpInfoRow extends StatelessWidget {
  const _FreeUpInfoRow({required this.icon, required this.titleWidget});

  final IconData icon;
  final Widget titleWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: titleWidget),
        ],
      ),
    );
  }
}

class _FreeUpSpaceIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 168;
    canvas.save();
    canvas.scale(scale);

    final dark = Paint()..color = const Color(0xFF3D4246);
    final outline = Paint()..color = const Color(0xFF5D646A);
    final coral = Paint()..color = const Color(0xFFF1665F);
    final grey = Paint()..color = const Color(0xFF8D9498);
    final yellow = Paint()..color = const Color(0xFFFFD04D);

    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(38, 0, 92, 176),
      const Radius.circular(12),
    );
    canvas.drawRRect(phone, outline);

    canvas.save();
    canvas.clipRRect(phone);
    canvas.drawRect(const Rect.fromLTWH(44, 16, 80, 58), coral);
    canvas.drawRect(const Rect.fromLTWH(44, 74, 80, 58), coral);
    canvas.drawRect(const Rect.fromLTWH(44, 132, 80, 44), coral);

    final linePaint = Paint()
      ..color = dark.color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(86, 16), const Offset(86, 176), linePaint);
    canvas.drawLine(const Offset(44, 74), const Offset(124, 74), linePaint);
    canvas.drawLine(const Offset(44, 132), const Offset(124, 132), linePaint);
    canvas.drawLine(const Offset(65, 132), const Offset(65, 176), linePaint);

    final wave = Path()
      ..moveTo(44, 106)
      ..quadraticBezierTo(54, 120, 64, 106)
      ..quadraticBezierTo(74, 120, 84, 106)
      ..quadraticBezierTo(94, 120, 104, 106)
      ..quadraticBezierTo(114, 120, 124, 106)
      ..lineTo(124, 132)
      ..lineTo(44, 132)
      ..close();
    canvas.drawPath(wave, grey);

    final beak = Path()
      ..moveTo(64, 54)
      ..lineTo(84, 66)
      ..lineTo(73, 76)
      ..close();
    canvas.drawPath(beak, yellow);

    final body = Path()
      ..moveTo(83, 55)
      ..lineTo(116, 105)
      ..lineTo(80, 104)
      ..quadraticBezierTo(62, 101, 63, 82)
      ..quadraticBezierTo(64, 66, 83, 55)
      ..close();
    canvas.drawPath(body, dark);

    final wing = Paint()..color = const Color(0xFF363B3F);
    final wingPath = Path()
      ..moveTo(82, 62)
      ..lineTo(122, 106)
      ..lineTo(72, 79)
      ..close();
    canvas.drawPath(wingPath, wing);
    canvas.drawCircle(const Offset(77, 62), 10, dark);
    canvas.drawCircle(const Offset(77, 62), 4.4, Paint()..color = grey.color);

    final leg = Paint()
      ..color = dark.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(86, 103)
        ..quadraticBezierTo(84, 119, 78, 128),
      leg,
    );

    canvas.restore();

    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
    canvas.drawOval(const Rect.fromLTWH(48, 170, 72, 14), shadow);

    final barBg = Paint()..color = outline.color;
    final barFg = Paint()..color = coral.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 190, 112, 10),
        const Radius.circular(6),
      ),
      barBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 190, 104, 10),
        const Radius.circular(6),
      ),
      barFg,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
