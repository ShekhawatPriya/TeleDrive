part of '../free_up_space_screen.dart';

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
