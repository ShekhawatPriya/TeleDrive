part of '../social_icons.dart';

class YouTubeIcon extends StatelessWidget {
  const YouTubeIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _YouTubePainter(color)),
    );
  }
}

class _YouTubePainter extends CustomPainter {
  _YouTubePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final path = Path();

    path.moveTo(23.498 * scaleX, 6.186 * scaleY);
    path.arcToPoint(
      Offset(21.376 * scaleX, 4.05 * scaleY),
      radius: Radius.elliptical(3.016 * scaleX, 3.016 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      19.505 * scaleX,
      3.545 * scaleY,
      12.0 * scaleX,
      3.545 * scaleY,
      12.0 * scaleX,
      3.545 * scaleY,
    );
    path.cubicTo(
      12.0 * scaleX,
      3.545 * scaleY,
      4.495 * scaleX,
      3.545 * scaleY,
      2.623 * scaleX,
      4.05 * scaleY,
    );
    path.arcToPoint(
      Offset(0.502 * scaleX, 6.186 * scaleY),
      radius: Radius.elliptical(3.017 * scaleX, 3.017 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      0.0 * scaleX,
      8.07 * scaleY,
      0.0 * scaleX,
      12.0 * scaleY,
      0.0 * scaleX,
      12.0 * scaleY,
    );
    path.cubicTo(
      0.0 * scaleX,
      12.0 * scaleY,
      0.0 * scaleX,
      15.93 * scaleY,
      0.502 * scaleX,
      17.814 * scaleY,
    );
    path.arcToPoint(
      Offset(2.624 * scaleX, 19.95 * scaleY),
      radius: Radius.elliptical(3.016 * scaleX, 3.016 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      4.495 * scaleX,
      19.95 * scaleY,
      12.0 * scaleX,
      19.95 * scaleY,
      12.0 * scaleX,
      19.95 * scaleY,
    );
    path.cubicTo(
      12.0 * scaleX,
      19.95 * scaleY,
      19.505 * scaleX,
      19.95 * scaleY,
      21.377 * scaleX,
      19.95 * scaleY,
    );
    path.arcToPoint(
      Offset(23.499 * scaleX, 17.814 * scaleY),
      radius: Radius.elliptical(3.015 * scaleX, 3.015 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      24.0 * scaleX,
      15.93 * scaleY,
      24.0 * scaleX,
      12.0 * scaleY,
      24.0 * scaleX,
      12.0 * scaleY,
    );
    path.cubicTo(
      24.0 * scaleX,
      12.0 * scaleY,
      24.0 * scaleX,
      8.07 * scaleY,
      23.498 * scaleX,
      6.186 * scaleY,
    );
    path.close();

    // Triangle cutout in the center
    path.moveTo(9.545 * scaleX, 15.568 * scaleY);
    path.lineTo(9.545 * scaleX, 8.432 * scaleY);
    path.lineTo(15.818 * scaleX, 12.0 * scaleY);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
