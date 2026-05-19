/// Material 3 state-layer opacities.
///
/// These multiply against the role color (e.g. onSurface, primary) to draw
/// the hover / focus / pressed / dragged overlays. Flutter applies these
/// automatically when a `WidgetStateProperty<Color?>` returns a color with
/// the right alpha — these constants keep ad-hoc overrides consistent.
class AppStateLayer {
  static const double hovered = 0.08;
  static const double focused = 0.10;
  static const double pressed = 0.10;
  static const double dragged = 0.16;

  /// M3 disabled-content opacity, used for foreground (text/icons).
  static const double disabledContent = 0.38;

  /// M3 disabled-container opacity, used for background fills.
  static const double disabledContainer = 0.12;
}
