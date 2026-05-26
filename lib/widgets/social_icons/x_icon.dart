part of '../social_icons.dart';

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
