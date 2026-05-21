import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canFree = formatFileSize(cache.totalSize);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 36,
                  tooltip: 'Close',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 54),
                      Center(
                        child: CustomPaint(
                          size: const Size(168, 220),
                          painter: _FreeUpSpaceIllustrationPainter(),
                        ),
                      ),
                      const SizedBox(height: 56),
                      Text(
                        'Free up space on this device',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w400,
                          height: 1.14,
                        ),
                      ),
                      const SizedBox(height: 44),
                      _FreeUpInfoRow(
                        icon: Icons.cloud_done_outlined,
                        text:
                            'These items are already safely backed up to Telegram Drive.',
                      ),
                      const SizedBox(height: 34),
                      _FreeUpInfoRow(
                        icon: Icons.fact_check_outlined,
                        text:
                            'You can still view them at any time in Telegram Drive.',
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
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
          onPressed: () {},
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text('Free up $canFree'),
        ),
      ),
    );
  }
}

class _FreeUpInfoRow extends StatelessWidget {
  const _FreeUpInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 52, child: Icon(icon, color: scheme.primary, size: 32)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ),
      ],
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
