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
      child: CustomPaint(painter: _GitHubPainter(color)),
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

    path.cubicTo(
      3.58 * scaleX,
      0 * scaleY,
      0 * scaleX,
      3.58 * scaleY,
      0 * scaleX,
      8 * scaleY,
    );
    path.cubicTo(
      0 * scaleX,
      11.54 * scaleY,
      2.29 * scaleX,
      14.53 * scaleY,
      5.47 * scaleX,
      15.59 * scaleY,
    );
    path.cubicTo(
      5.87 * scaleX,
      15.66 * scaleY,
      6.02 * scaleX,
      15.42 * scaleY,
      6.02 * scaleX,
      15.21 * scaleY,
    );
    path.cubicTo(
      6.02 * scaleX,
      15.02 * scaleY,
      6.01 * scaleX,
      14.39 * scaleY,
      6.01 * scaleX,
      13.72 * scaleY,
    );
    path.cubicTo(
      4.0 * scaleX,
      14.09 * scaleY,
      3.48 * scaleX,
      13.23 * scaleY,
      3.32 * scaleX,
      12.78 * scaleY,
    );
    path.cubicTo(
      3.23 * scaleX,
      12.55 * scaleY,
      2.84 * scaleX,
      11.84 * scaleY,
      2.5 * scaleX,
      11.65 * scaleY,
    );
    path.cubicTo(
      2.22 * scaleX,
      11.5 * scaleY,
      1.82 * scaleX,
      11.13 * scaleY,
      2.49 * scaleX,
      11.12 * scaleY,
    );
    path.cubicTo(
      3.12 * scaleX,
      11.11 * scaleY,
      3.57 * scaleX,
      11.7 * scaleY,
      3.72 * scaleX,
      11.94 * scaleY,
    );
    path.cubicTo(
      4.44 * scaleX,
      13.15 * scaleY,
      5.59 * scaleX,
      12.81 * scaleY,
      6.05 * scaleX,
      12.6 * scaleY,
    );
    path.cubicTo(
      6.12 * scaleX,
      12.08 * scaleY,
      6.33 * scaleX,
      11.73 * scaleY,
      6.56 * scaleX,
      11.53 * scaleY,
    );
    path.cubicTo(
      4.78 * scaleX,
      11.33 * scaleY,
      2.92 * scaleX,
      10.64 * scaleY,
      2.92 * scaleX,
      7.58 * scaleY,
    );
    path.cubicTo(
      2.92 * scaleX,
      6.71 * scaleY,
      3.23 * scaleX,
      5.99 * scaleY,
      3.74 * scaleX,
      5.43 * scaleY,
    );
    path.cubicTo(
      3.66 * scaleX,
      5.23 * scaleY,
      3.38 * scaleX,
      4.41 * scaleY,
      3.82 * scaleX,
      3.31 * scaleY,
    );
    path.cubicTo(
      3.82 * scaleX,
      3.31 * scaleY,
      4.49 * scaleX,
      3.1 * scaleY,
      6.02 * scaleX,
      4.13 * scaleY,
    );
    path.cubicTo(
      6.66 * scaleX,
      3.95 * scaleY,
      7.34 * scaleX,
      3.86 * scaleY,
      8.02 * scaleX,
      3.86 * scaleY,
    );
    path.cubicTo(
      8.7 * scaleX,
      3.86 * scaleY,
      9.38 * scaleX,
      3.95 * scaleY,
      10.02 * scaleX,
      4.13 * scaleY,
    );
    path.cubicTo(
      11.55 * scaleX,
      3.09 * scaleY,
      12.22 * scaleX,
      3.31 * scaleY,
      12.22 * scaleX,
      3.31 * scaleY,
    );
    path.cubicTo(
      12.66 * scaleX,
      4.41 * scaleY,
      12.38 * scaleX,
      5.23 * scaleY,
      12.3 * scaleX,
      5.43 * scaleY,
    );
    path.cubicTo(
      12.81 * scaleX,
      5.99 * scaleY,
      13.12 * scaleX,
      6.71 * scaleY,
      13.12 * scaleX,
      7.58 * scaleY,
    );
    path.cubicTo(
      13.12 * scaleX,
      10.65 * scaleY,
      11.25 * scaleX,
      11.33 * scaleY,
      9.47 * scaleX,
      11.53 * scaleY,
    );
    path.cubicTo(
      9.76 * scaleX,
      11.78 * scaleY,
      10.01 * scaleX,
      12.26 * scaleY,
      10.01 * scaleX,
      13.01 * scaleY,
    );
    path.cubicTo(
      10.01 * scaleX,
      14.08 * scaleY,
      10.0 * scaleX,
      14.94 * scaleY,
      10.0 * scaleX,
      15.21 * scaleY,
    );
    path.cubicTo(
      10.0 * scaleX,
      15.42 * scaleY,
      10.15 * scaleX,
      15.67 * scaleY,
      10.55 * scaleX,
      15.59 * scaleY,
    );
    path.cubicTo(
      13.73 * scaleX,
      14.53 * scaleY,
      16.0 * scaleX,
      11.54 * scaleY,
      16.0 * scaleX,
      8.0 * scaleY,
    );
    path.cubicTo(
      16.0 * scaleX,
      3.58 * scaleY,
      12.42 * scaleX,
      0 * scaleY,
      8.0 * scaleX,
      0 * scaleY,
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

class XIcon extends StatelessWidget {
  const XIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _XPainter(color)),
    );
  }
}

class _XPainter extends CustomPainter {
  _XPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    // Main X paths (derived from SVG)
    path.moveTo(18.244 * scaleX, 2.25 * scaleY);
    path.lineTo((18.244 + 3.308) * scaleX, 2.25 * scaleY);
    path.lineTo((18.244 + 3.308 - 7.227) * scaleX, (2.25 + 8.26) * scaleY);
    path.lineTo((14.325 + 8.502) * scaleX, (10.51 + 11.24) * scaleY);
    path.lineTo(16.17 * scaleX, 21.75 * scaleY);
    path.lineTo((16.17 - 5.214) * scaleX, (21.75 - 6.817) * scaleY);
    path.lineTo(4.99 * scaleX, 21.75 * scaleY);
    path.lineTo(1.68 * scaleX, 21.75 * scaleY);
    path.lineTo((1.68 + 7.73) * scaleX, (21.75 - 8.835) * scaleY);
    path.lineTo(1.254 * scaleX, 2.25 * scaleY);
    path.lineTo(8.08 * scaleX, 2.25 * scaleY);
    path.lineTo((8.08 + 4.713) * scaleX, (2.25 + 6.231) * scaleY);
    path.close();

    // Second sub-path to cut out center of the thin line
    path.moveTo(17.083 * scaleX, 19.77 * scaleY);
    path.lineTo((17.083 + 1.833) * scaleX, 19.77 * scaleY);
    path.lineTo(7.084 * scaleX, 4.126 * scaleY);
    path.lineTo(5.117 * scaleX, 4.126 * scaleY);
    path.close();

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
      19.505 * scaleX, 3.545 * scaleY,
      12.0 * scaleX, 3.545 * scaleY,
      12.0 * scaleX, 3.545 * scaleY,
    );
    path.cubicTo(
      12.0 * scaleX, 3.545 * scaleY,
      4.495 * scaleX, 3.545 * scaleY,
      2.623 * scaleX, 4.05 * scaleY,
    );
    path.arcToPoint(
      Offset(0.502 * scaleX, 6.186 * scaleY),
      radius: Radius.elliptical(3.017 * scaleX, 3.017 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      0.0 * scaleX, 8.07 * scaleY,
      0.0 * scaleX, 12.0 * scaleY,
      0.0 * scaleX, 12.0 * scaleY,
    );
    path.cubicTo(
      0.0 * scaleX, 12.0 * scaleY,
      0.0 * scaleX, 15.93 * scaleY,
      0.502 * scaleX, 17.814 * scaleY,
    );
    path.arcToPoint(
      Offset(2.624 * scaleX, 19.95 * scaleY),
      radius: Radius.elliptical(3.016 * scaleX, 3.016 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      4.495 * scaleX, 19.95 * scaleY,
      12.0 * scaleX, 19.95 * scaleY,
      12.0 * scaleX, 19.95 * scaleY,
    );
    path.cubicTo(
      12.0 * scaleX, 19.95 * scaleY,
      19.505 * scaleX, 19.95 * scaleY,
      21.377 * scaleX, 19.95 * scaleY,
    );
    path.arcToPoint(
      Offset(23.499 * scaleX, 17.814 * scaleY),
      radius: Radius.elliptical(3.015 * scaleX, 3.015 * scaleY),
      clockwise: false,
    );
    path.cubicTo(
      24.0 * scaleX, 15.93 * scaleY,
      24.0 * scaleX, 12.0 * scaleY,
      24.0 * scaleX, 12.0 * scaleY,
    );
    path.cubicTo(
      24.0 * scaleX, 12.0 * scaleY,
      24.0 * scaleX, 8.07 * scaleY,
      23.498 * scaleX, 6.186 * scaleY,
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
