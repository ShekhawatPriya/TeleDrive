import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A quiet identity mark, with a tactile inset rather than decorative animation.
class LoginIdentity extends StatelessWidget {
  const LoginIdentity({required this.step, super.key});
  final int step;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    return ExcludeSemantics(
      child: Container(
        width: 80,
        height: 80,
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: .12),
              scheme.primary.withValues(alpha: .035),
            ],
          ),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: scheme.primary.withValues(alpha: .10)),
          ),
        ),
        child: Icon(
          switch (step) {
            0 => ios ? CupertinoIcons.paperplane_fill : Icons.send_rounded,
            1 =>
              ios
                  ? CupertinoIcons.bubble_left_bubble_right
                  : Icons.sms_outlined,
            _ => ios ? CupertinoIcons.lock_shield : Icons.shield_outlined,
          },
          color: scheme.primary,
          size: 36,
        ),
      ),
    );
  }
}
