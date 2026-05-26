part of '../google_drive_icon.dart';

class _PdfBadge extends StatelessWidget {
  const _PdfBadge({required this.size, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? const Color(0xFFEA4335); // Warm Google Red
    final borderRadius = size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'PDF',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: -0.5,
            height: 1.0,
            fontFamily: 'Roboto', // Fallback to standard clean sans-serif
          ),
        ),
      ),
    );
  }
}
