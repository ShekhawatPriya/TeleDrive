import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

  Future<void> _launchTelegramPrivacy() async {
    final uri = Uri.parse('https://telegram.org/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Your data in Telegram Drive'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg + 4,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centered vibrant Telegram Shield
                const SizedBox(height: AppSpacing.md),
                const Center(child: TelegramDataShield(size: 130)),
                const SizedBox(height: AppSpacing.xl + 8),

                // Headline
                Text(
                  "Your photos and videos, and their data, are safe within Telegram Drive",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Bullet Points
                _buildBulletRow(
                  context,
                  icon: Icons.lock_outline_rounded,
                  text:
                      "We secure your files using Telegram's distributed cloud infrastructure and local encryption to protect what you back up or share.",
                ),
                const SizedBox(height: AppSpacing.lg + 4),
                _buildBulletRow(
                  context,
                  icon: Icons.visibility_off_outlined,
                  text:
                      "We never sell your photos or videos, and we don't use your personal data for advertising or ad-targeting.",
                ),
                const SizedBox(height: AppSpacing.lg + 4),
                _buildBulletRow(
                  context,
                  icon: Icons.info_outline,
                  text:
                      "You remain in complete control of how you share your files and who can access them.",
                ),
                const SizedBox(height: AppSpacing.xxl + 8),

                // Bottom Link documentation explanation
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: "Visit the "),
                      TextSpan(
                        text: "Telegram Privacy Policy",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _launchTelegramPrivacy,
                      ),
                      const TextSpan(
                        text:
                            " to discover all the ways that TeleDrive keeps your files and memories safe.",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md + 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class TelegramDataShield extends StatelessWidget {
  const TelegramDataShield({super.key, this.size = 130});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Harmonious blue/cyan shade matching Telegram identity
    final Color leftColor = isDark
        ? const Color(0xFF54B4E6)
        : const Color(0xFF35A3E6);
    final Color rightColor = isDark
        ? const Color(0xFF229ED9)
        : const Color(0xFF1B82B5);

    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ShieldPainter(
                leftColor: leftColor,
                rightColor: rightColor,
              ),
            ),
          ),
          // Official Telegram Logo inside a white circular badge
          Positioned(
            child: Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/icon/telegram.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;

  _ShieldPainter({required this.leftColor, required this.rightColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Curved shield left path
    final leftPath = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.35, 0, w * 0.08, h * 0.06, 0, h * 0.12)
      ..lineTo(0, h * 0.52)
      ..cubicTo(0, h * 0.76, w * 0.22, h * 0.93, w / 2, h)
      ..lineTo(w / 2, 0)
      ..close();

    // Curved shield right path
    final rightPath = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.65, 0, w * 0.92, h * 0.06, w, h * 0.12)
      ..lineTo(w, h * 0.52)
      ..cubicTo(w, h * 0.76, w * 0.78, h * 0.93, w / 2, h)
      ..lineTo(w / 2, 0)
      ..close();

    final paintLeft = Paint()
      ..color = leftColor
      ..style = PaintingStyle.fill;

    final paintRight = Paint()
      ..color = rightColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(leftPath, paintLeft);
    canvas.drawPath(rightPath, paintRight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
