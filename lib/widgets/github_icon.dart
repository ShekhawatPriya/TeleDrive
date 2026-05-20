import 'package:flutter/material.dart';

class GitHubIcon extends StatelessWidget {
  const GitHubIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GitHubPainter(color),
      ),
    );
  }
}

class _GitHubPainter extends CustomPainter {
  _GitHubPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    final scaleX = size.width / 16.0;
    final scaleY = size.height / 16.0;
    
    path.moveTo(8 * scaleX, 0 * scaleY);
    
    path.cubicTo(3.58 * scaleX, 0 * scaleY, 0 * scaleX, 3.58 * scaleY, 0 * scaleX, 8 * scaleY);
    path.cubicTo(0 * scaleX, 11.54 * scaleY, 2.29 * scaleX, 14.53 * scaleY, 5.47 * scaleX, 15.59 * scaleY);
    path.cubicTo(5.87 * scaleX, 15.66 * scaleY, 6.02 * scaleX, 15.42 * scaleY, 6.02 * scaleX, 15.21 * scaleY);
    path.cubicTo(6.02 * scaleX, 15.02 * scaleY, 6.01 * scaleX, 14.39 * scaleY, 6.01 * scaleX, 13.72 * scaleY);
    path.cubicTo(4.0 * scaleX, 14.09 * scaleY, 3.48 * scaleX, 13.23 * scaleY, 3.32 * scaleX, 12.78 * scaleY);
    path.cubicTo(3.23 * scaleX, 12.55 * scaleY, 2.84 * scaleX, 11.84 * scaleY, 2.5 * scaleX, 11.65 * scaleY);
    path.cubicTo(2.22 * scaleX, 11.5 * scaleY, 1.82 * scaleX, 11.13 * scaleY, 2.49 * scaleX, 11.12 * scaleY);
    path.cubicTo(3.12 * scaleX, 11.11 * scaleY, 3.57 * scaleX, 11.7 * scaleY, 3.72 * scaleX, 11.94 * scaleY);
    path.cubicTo(4.44 * scaleX, 13.15 * scaleY, 5.59 * scaleX, 12.81 * scaleY, 6.05 * scaleX, 12.6 * scaleY);
    path.cubicTo(6.12 * scaleX, 12.08 * scaleY, 6.33 * scaleX, 11.73 * scaleY, 6.56 * scaleX, 11.53 * scaleY);
    path.cubicTo(4.78 * scaleX, 11.33 * scaleY, 2.92 * scaleX, 10.64 * scaleY, 2.92 * scaleX, 7.58 * scaleY);
    path.cubicTo(2.92 * scaleX, 6.71 * scaleY, 3.23 * scaleX, 5.99 * scaleY, 3.74 * scaleX, 5.43 * scaleY);
    path.cubicTo(3.66 * scaleX, 5.23 * scaleY, 3.38 * scaleX, 4.41 * scaleY, 3.82 * scaleX, 3.31 * scaleY);
    path.cubicTo(3.82 * scaleX, 3.31 * scaleY, 4.49 * scaleX, 3.1 * scaleY, 6.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(6.66 * scaleX, 3.95 * scaleY, 7.34 * scaleX, 3.86 * scaleY, 8.02 * scaleX, 3.86 * scaleY);
    path.cubicTo(8.7 * scaleX, 3.86 * scaleY, 9.38 * scaleX, 3.95 * scaleY, 10.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(11.55 * scaleX, 3.09 * scaleY, 12.22 * scaleX, 3.31 * scaleY, 12.22 * scaleX, 3.31 * scaleY);
    path.cubicTo(12.66 * scaleX, 4.41 * scaleY, 12.38 * scaleX, 5.23 * scaleY, 12.3 * scaleX, 5.43 * scaleY);
    path.cubicTo(12.81 * scaleX, 5.99 * scaleY, 13.12 * scaleX, 6.71 * scaleY, 13.12 * scaleX, 7.58 * scaleY);
    path.cubicTo(13.12 * scaleX, 10.65 * scaleY, 11.25 * scaleX, 11.33 * scaleY, 9.47 * scaleX, 11.53 * scaleY);
    path.cubicTo(9.76 * scaleX, 11.78 * scaleY, 10.01 * scaleX, 12.26 * scaleY, 10.01 * scaleX, 13.01 * scaleY);
    path.cubicTo(10.01 * scaleX, 14.08 * scaleY, 10.0 * scaleX, 14.94 * scaleY, 10.0 * scaleX, 15.21 * scaleY);
    path.cubicTo(10.0 * scaleX, 15.42 * scaleY, 10.15 * scaleX, 15.67 * scaleY, 10.55 * scaleX, 15.59 * scaleY);
    path.cubicTo(13.73 * scaleX, 14.53 * scaleY, 16.0 * scaleX, 11.54 * scaleY, 16.0 * scaleX, 8.0 * scaleY);
    path.cubicTo(16.0 * scaleX, 3.58 * scaleY, 12.42 * scaleX, 0 * scaleY, 8.0 * scaleX, 0 * scaleY);
    
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
