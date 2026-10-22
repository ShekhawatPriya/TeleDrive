import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'ios/ios_accessibility.dart';

/// A Liquid Glass capsule drawn by UIKit behind Flutter content, for floating
/// chrome that holds text or a scrubber (the photo viewer's title and video
/// transport). UIKit never receives touches; the [child] keeps them.
///
/// Older iOS, Reduce Transparency, high contrast, Android and widget tests get
/// an opaque capsule matching [NativeGlassButton]'s fallback.
class NativeGlassSurface extends StatefulWidget {
  const NativeGlassSurface({required this.child, this.dark = true, super.key});
  final Widget child;

  /// Dark glass (white content) or light glass (dark content).
  final bool dark;

  /// Opaque fallback color for [dark].
  static Color fallbackColor(bool dark) =>
      dark ? const Color(0xCC252529) : const Color(0xF2F2F2F7);

  @override
  State<NativeGlassSurface> createState() => _NativeGlassSurfaceState();
}

class _NativeGlassSurfaceState extends State<NativeGlassSurface> {
  static Future<bool>? _supported;
  bool _available = false;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    (_supported ??= _query()).then((value) {
      if (mounted && value) setState(() => _available = true);
    });
  }

  static Future<bool> _query() async {
    try {
      return await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsGlass') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant NativeGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) {
      _channel
          ?.invokeMethod<void>('update', {'dark': widget.dark})
          .catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass =
        _available &&
        Theme.of(context).platform == TargetPlatform.iOS &&
        !MediaQuery.highContrastOf(context) &&
        !IosAccessibilityPreferences.reduceTransparencyOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: glass
              ? UiKitView(
                  viewType: 'teledrive/glass-surface',
                  hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                  creationParamsCodec: const StandardMessageCodec(),
                  creationParams: {'dark': widget.dark},
                  onPlatformViewCreated: (id) =>
                      _channel = MethodChannel('teledrive/glass-surface/$id'),
                )
              : DecoratedBox(
                  key: const ValueKey('glass-surface-fallback'),
                  decoration: ShapeDecoration(
                    color: NativeGlassSurface.fallbackColor(widget.dark),
                    shape: StadiumBorder(
                      side: MediaQuery.highContrastOf(context)
                          ? BorderSide(
                              color: widget.dark ? Colors.white : Colors.black,
                            )
                          : BorderSide.none,
                    ),
                  ),
                ),
        ),
        widget.child,
      ],
    );
  }
}
