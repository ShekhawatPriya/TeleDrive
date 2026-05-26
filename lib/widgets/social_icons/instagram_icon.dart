part of '../social_icons.dart';

class InstagramIcon extends StatelessWidget {
  const InstagramIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _InstagramPainter(color)),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  _InstagramPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final strokeWidth = 2.163 * scaleX;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw outer rounded rectangle
    final halfStroke = strokeWidth / 2;
    final rect = RRect.fromLTRBXY(
      halfStroke,
      halfStroke,
      size.width - halfStroke,
      size.height - halfStroke,
      6.0 * scaleX,
      6.0 * scaleY,
    );
    canvas.drawRRect(rect, borderPaint);

    // Draw center circle
    canvas.drawCircle(
      Offset(12.0 * scaleX, 12.0 * scaleY),
      5.081 * scaleX,
      borderPaint,
    );

    // Draw flash dot (filled circle)
    canvas.drawCircle(
      Offset(18.2 * scaleX, 5.8 * scaleY),
      1.44 * scaleX,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
