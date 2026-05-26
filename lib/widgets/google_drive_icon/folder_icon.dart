part of '../google_drive_icon.dart';

class _FolderIcon extends StatelessWidget {
  const _FolderIcon({
    required this.size,
    required this.isShared,
    required this.color,
  });

  final double size;
  final bool isShared;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FolderPainter(isShared: isShared, color: color),
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.isShared, required this.color});

  final bool isShared;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.08; // border radius
    final tabW = w * 0.45;
    final tabH = h * 0.16;
    final pocketTop = h * 0.28;

    final backPath = Path()
      ..moveTo(r, 0)
      ..lineTo(tabW - r, 0)
      ..quadraticBezierTo(
        tabW,
        0,
        tabW + (w * 0.05),
        tabH,
      ) // smooth transition down
      ..lineTo(w - r, tabH)
      ..arcToPoint(Offset(w, tabH + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    final backPaint = Paint()
      ..color = color
          .withValues(
            alpha: 0.72,
          ) // 3D background shading (darker tab background)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backPath, backPaint);

    final frontPath = Path()
      ..moveTo(0, pocketTop + r)
      ..arcToPoint(Offset(r, pocketTop), radius: Radius.circular(r))
      ..lineTo(w - r, pocketTop)
      ..arcToPoint(Offset(w, pocketTop + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..close();

    final frontPaint = Paint()
      ..color =
          color // Crisp foreground layer
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontPath, frontPaint);

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;
    canvas.drawLine(
      Offset(r, pocketTop),
      Offset(w - r, pocketTop),
      borderPaint,
    );

    if (isShared) {
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final pocketH = h - pocketTop;
      final headRadius = pocketH * 0.15;
      final headCX = w * 0.50;
      final headCY = pocketTop + (pocketH * 0.35);

      canvas.drawCircle(Offset(headCX, headCY), headRadius, whitePaint);

      final bodyW = pocketH * 0.50;
      final bodyH = pocketH * 0.28;
      final bodyRect = Rect.fromCenter(
        center: Offset(
          headCX,
          headCY + headRadius + bodyH / 2 + (pocketH * 0.03),
        ),
        width: bodyW,
        height: bodyH,
      );

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          bodyRect,
          topLeft: Radius.circular(bodyW * 0.3),
          topRight: Radius.circular(bodyW * 0.3),
        ),
        whitePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) {
    return oldDelegate.isShared != isShared || oldDelegate.color != color;
  }
}
