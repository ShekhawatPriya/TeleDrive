import 'package:flutter/material.dart';

/// Decorative, code-drawn collection. No demo files are mixed into user data.
class LandingCollectionArt extends StatelessWidget {
  const LandingCollectionArt({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.65,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
              Positioned(
                left: box.maxWidth * .12,
                top: 28,
                bottom: 26,
                width: box.maxWidth * .4,
                child: Transform.rotate(
                  angle: -.12,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: .10),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_rounded,
                          color: scheme.primary,
                          size: 32,
                        ),
                        const Spacer(),
                        for (final width in [1.0, .8, .55])
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FractionallySizedBox(
                              widthFactor: width,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: box.maxWidth * .1,
                top: 30,
                bottom: 22,
                width: box.maxWidth * .43,
                child: Transform.rotate(
                  angle: .10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: .14),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        painter: _LandscapePainter(),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 16,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primaryContainer,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: scheme.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF94B5C5), Color(0xFFE7E4CD)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .25),
      size.width * .10,
      Paint()..color = const Color(0xFFFFF4D6),
    );
    final back = Path()
      ..moveTo(0, size.height * .68)
      ..lineTo(size.width * .45, size.height * .36)
      ..lineTo(size.width, size.height * .7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF648A87));
    final front = Path()
      ..moveTo(0, size.height * .82)
      ..quadraticBezierTo(
        size.width * .4,
        size.height * .54,
        size.width,
        size.height * .78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF274F53));
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) => false;
}
