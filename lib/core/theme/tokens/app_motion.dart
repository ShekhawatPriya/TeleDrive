import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Material 3 motion duration tokens.
///
/// Map to "short1..long4" from the M3 motion spec. Pick by surface size:
/// micro-interaction (selection, ripple) → short1/short2;
/// component-level (snackbar, sheet, dialog) → medium1..medium3;
/// full-screen / hero → long1..long4.
class AppDurations {
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 550);
  static const long4 = Duration(milliseconds: 600);
}

/// Material 3 easing curves.
///
/// Use [emphasized] for entering elements, [emphasizedDecelerate] for incoming
/// elements coming to rest, [emphasizedAccelerate] for outgoing elements
/// leaving the screen, and [standard] / [linear] for two-way / continuous
/// motion.
class AppEasing {
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Curves.easeInOut;
  static const Curve standardDecelerate = Curves.easeOut;
  static const Curve standardAccelerate = Curves.easeIn;
  static const Curve linear = Curves.linear;
}

/// UIKit-style spring (about 0.45 s response, slight overshoot), normalized
/// so the motion settles at the end of the animation's duration. Used for
/// entering motion on iOS, where native menus and sheets also spring.
class IosSpringCurve extends Curve {
  const IosSpringCurve({this.damping = .8, this.response = .42});

  /// Damping ratio below 1 gives a small, quickly settling overshoot.
  final double damping;

  /// Period of the undamped spring as a fraction of the duration.
  final double response;

  @override
  double transformInternal(double t) {
    final omega = 2 * math.pi / response;
    final decay = math.exp(-damping * omega * t);
    final damped = omega * math.sqrt(1 - damping * damping);
    return 1 -
        decay *
            (math.cos(damped * t) +
                damping * omega / damped * math.sin(damped * t));
  }
}

/// Entering curves by platform: springs on iOS, Material elsewhere.
abstract final class AdaptiveEasing {
  static const Curve iosSpring = IosSpringCurve();

  static Curve enter(TargetPlatform platform) => platform == TargetPlatform.iOS
      ? iosSpring
      : AppEasing.emphasizedDecelerate;
}
